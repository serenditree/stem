#!/usr/bin/env bash
########################################################################################################################
# LEAF
########################################################################################################################
_SERVICE=leaf
_ORDINAL=23

_IMAGE=serenditree/leaf
_VERSION=latest
_TAG=$_VERSION

if [[ -n "$_ARG_COMPOSE" ]]; then
    _CONFIG='compose'
    _TAG=$_CONFIG
else
    _CONFIG='prod'
fi

_CONTAINER=$_SERVICE

_VOLUME_SRC=$_ST_HOME_LEAF
_VOLUME_DST=${_ST_CONTAINER_ROOT}/src

_EXPOSE=8080/tcp

if [[ -n "$_ST_CONTEXT_TKN" ]]; then
    _QUALIFIED="${_ST_REGISTRY}/"
fi

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# BUILD
########################################################################################################################
if [[ " $* " =~ " build " ]]; then
    sc_heading 1 "Building ${_IMAGE}:${_TAG}"
    [[ -n "$_ARG_DRYRUN" ]] && exit 0
    _DESCRIPTION="Production image for leaf."
    _BUILDAH_ARGS="--volume ${_VOLUME_SRC}:${_VOLUME_DST}:rw,z "

    # STEP BUILD
    _CONTAINER_REF_1=$(buildah from $_BUILDAH_ARGS ${_QUALIFIED}serenditree/node-builder)

    echo "Building project..."
    buildah run $_CONTAINER_REF_1 -- yarn
    buildah run $_CONTAINER_REF_1 -- yarn run build --configuration="$_CONFIG"

    # STEP PACKAGE
    _CONTAINER_REF=$(buildah from $_ST_FROM_LEAF)

    echo "Upgrading distribution..."
    buildah run --user 0:0 $_CONTAINER_REF -- apt-get update
    buildah run --user 0:0 $_CONTAINER_REF -- apt-get dist-upgrade -y
    if [[ "$_CONFIG" == "compose" ]]; then
        echo "Installing curl..."
        buildah run --user 0:0 $_CONTAINER_REF -- apt-get install -y curl
    fi
    buildah run --user 0:0 $_CONTAINER_REF -- apt-get clean

    echo "Adding application..."
    buildah add --chown 1001:0 $_CONTAINER_REF ${_VOLUME_SRC}/dist/browser
    echo "Adding configuration..."
    _NGINX_CONFIG_FILE="serenditree.${_CONFIG}.conf"
    _SERVER_BLOCK=/opt/bitnami/nginx/conf/server_blocks/${_NGINX_CONFIG_FILE}
    buildah add --chown 1001:0 $_CONTAINER_REF src/${_NGINX_CONFIG_FILE} $_SERVER_BLOCK

    sc_label_rm $_ST_FROM_LEAF $_CONTAINER_REF
    sc_env_rm "$_CONTAINER_REF"

    buildah config --env DESCRIPTION="$_DESCRIPTION" $_CONTAINER_REF
    buildah config --label description="$_DESCRIPTION" $_CONTAINER_REF
    buildah config --port $_EXPOSE $_CONTAINER_REF

    sc_image_config_commit "$_SERVICE" "$_IMAGE" "$_VERSION" "$_TAG" "$_ORDINAL" "$_CONTAINER_REF"
########################################################################################################################
# UP
########################################################################################################################
elif [[ " $* " =~ " up " ]]; then
    if [[ -z "$_ST_CONTEXT_CLUSTER" ]]; then
        sc_heading 1 "Starting ${_SERVICE}:${_TAG}"
        sc_container_rm $_CONTAINER

        podman run \
            --user 0:0 \
            --log-level $_ST_LOG_LEVEL \
            --pod $_ST_POD \
            --name $_CONTAINER \
            --label serenditree.io/service=${_SERVICE} \
            --volume ${_VOLUME_SRC}:${_VOLUME_DST}:Z \
            --health-cmd "curl localhost:8080" \
            --health-interval 3s \
            --health-retries 1 \
            --detach \
            serenditree/node-builder:latest \
            yarn run host
    elif [[ -n "$_ARG_SETUP" ]]; then
        sc_heading 1 "Setting up ${_SERVICE}"

        [[ -z "$_ARG_DRYRUN" ]] && _ST_HELM_NAME=leaf
        helm $_ST_HELM_CMD $_ST_HELM_NAME ./charts/cd \
            --set "global.context=$_ST_CONTEXT" \
            --set "ingress.letsencrypt.issuer=$_ARG_ISSUER" | $_ST_HELM_PIPE


        if [[ -z "$_ARG_DRYRUN" ]]; then
            argocd app sync leaf
            argocd app wait leaf --health
        else
            helm $_ST_HELM_CMD $_ST_HELM_NAME ./charts/app \
                --set "global.context=$_ST_CONTEXT" \
                --set "ingress.letsencrypt.issuer=$_ARG_ISSUER" | $_ST_HELM_PIPE
        fi
    fi
########################################################################################################################
# DOWN
########################################################################################################################
elif [[ " $* " =~ " down " ]] && [[ -n "$_ST_CONTEXT_CLUSTER" ]]; then
    if [[ -n "$_ARG_DELETE" ]]; then
        sc_heading 1 "Deleting ${_SERVICE}"
        argocd app delete --yes $_SERVICE && echo "App deleted."
        helm uninstall $_SERVICE && echo "Release uninstalled."
    fi
########################################################################################################################
# TEKTON
########################################################################################################################
elif [[ " $* " =~ ( (tkn|tekton) ) ]]; then
    sc_heading 1 "Running tekton..."
    kubectl create --namespace tekton-pipelines -f ./charts/tkn/resources/run.yml &&
        sleep 1s &&
        tkn pipeline logs --namespace tekton-pipelines --last --follow leaf
fi
