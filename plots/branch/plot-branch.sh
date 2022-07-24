#!/usr/bin/env bash
_BRANCH=$1
_ROOT=$2
_OFFSET=$3
source ./plot.env
########################################################################################################################
# BRANCH
########################################################################################################################
_SERVICE=branch-${_BRANCH}
_ORDINAL="0$((_OFFSET + 15))"
_ORDINAL=${_ORDINAL: -2}

_IMAGE=serenditree/branch-${_BRANCH}
_VERSION=latest
_TAG=$_VERSION

_CONTAINER=$_SERVICE

_VOLUME_SRC_REPO=${HOME}/.m2/repository
_VOLUME_DST_REPO=${_ST_CONTAINER_ROOT}/.m2/repository
_VOLUME_SRC_SRC=${_ST_HOME_BRANCH}
_VOLUME_DST_SRC=${_ST_CONTAINER_ROOT}/src

_EXPOSE=8080/tcp

if [[ -n "$_ST_CONTEXT_TKN" ]]; then
    _QUALIFIED="${_ST_REGISTRY}/"
    #_BUILDAH_ARGS="--tls-verify=false"
    _VOLUME_SRC_REPO=$_ST_REPO
fi

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0):${_BRANCH}:${_ROOT}:${_OFFSET}"
fi
########################################################################################################################
# BUILD
########################################################################################################################
if [[ " $* " =~ " build " ]]; then
    sc_heading 1 "Building ${_IMAGE}:${_TAG}"
    [[ -n "$_ARG_DRYRUN" ]] && exit 0

    _DESCRIPTION="Production image for branch-${_BRANCH}."
    _BUILDAH_ARGS="--ulimit nofile=10240 "
    _BUILDAH_ARGS+="--volume ${_VOLUME_SRC_REPO}:${_VOLUME_DST_REPO}:rw,z "

    # STEP BUILD
    _CONTAINER_REF_1=$(buildah from $_BUILDAH_ARGS ${_QUALIFIED}serenditree/java-builder)
    _MOUNT_REF_1=$(buildah mount $_CONTAINER_REF_1)

    buildah config --env SERENDITREE_BRANCH=$_BRANCH $_CONTAINER_REF_1
    buildah config --workingdir $_VOLUME_DST_SRC $_CONTAINER_REF_1

    echo "Adding source from ${_VOLUME_SRC_SRC}..."
    buildah add $_CONTAINER_REF_1 $_VOLUME_SRC_SRC

    buildah run $_CONTAINER_REF_1 -- mvn clean install --also-make --projects leaves/leaf-${_BRANCH}
    if [[ -n "$_ST_CONTEXT_TKN" ]]; then
        buildah run $_CONTAINER_REF_1 -- chmod -R g=u $_VOLUME_DST_REPO
    fi

    # STEP PACKAGE
    _CONTAINER_REF=$(buildah from $_BUILDAH_ARGS ${_QUALIFIED}serenditree/java-base)

    buildah add --chown 1001:0 $_CONTAINER_REF \
        ${_MOUNT_REF_1:?}/serenditree/src/leaves/leaf-${_BRANCH}/target/quarkus-app/lib/ \
        ${_ST_CONTAINER_ROOT}/lib/
    buildah add --chown 1001:0 $_CONTAINER_REF \
        ${_MOUNT_REF_1:?}/serenditree/src/leaves/leaf-${_BRANCH}/target/quarkus-app/*.jar \
        ${_ST_CONTAINER_ROOT}/
    buildah add --chown 1001:0 $_CONTAINER_REF \
        ${_MOUNT_REF_1:?}/serenditree/src/leaves/leaf-${_BRANCH}/target/quarkus-app/app/ \
        ${_ST_CONTAINER_ROOT}/app/
    buildah add --chown 1001:0 $_CONTAINER_REF \
        ${_MOUNT_REF_1:?}/serenditree/src/leaves/leaf-${_BRANCH}/target/quarkus-app/quarkus/ \
        ${_ST_CONTAINER_ROOT}/quarkus/

    buildah config --user 1001:0 $_CONTAINER_REF

    buildah config --cmd "${_ST_CONTAINER_ROOT}/run.sh" $_CONTAINER_REF

    # CLEANUP
    buildah umount $_CONTAINER_REF_1
    buildah rm $_CONTAINER_REF_1

    buildah config --env SERENDITREE_BRANCH=$_BRANCH $_CONTAINER_REF
    buildah config --env DESCRIPTION="$_DESCRIPTION" $_CONTAINER_REF
    buildah config --label description="$_DESCRIPTION" $_CONTAINER_REF
    buildah config --port $_EXPOSE $_CONTAINER_REF

    sc_image_config_commit "$_SERVICE" "$_IMAGE" "$_VERSION" "$_TAG" "$_ORDINAL" "$_CONTAINER_REF"
########################################################################################################################
# UP
########################################################################################################################
elif [[ " $* " =~ " up " ]]; then
    source ./plot-branch-src.sh
    if [[ -z "$_ST_CONTEXT_CLUSTER" ]]; then
        sc_heading 1 "Starting ${_SERVICE}:${_TAG}"
        sc_container_rm $_CONTAINER
        _EXPOSE="$((${_EXPOSE%/*} + _OFFSET))"

        cat <(sc_branch_secrets podman) <(echo "serenditree/java-builder:latest bash wrapper.sh") | xargs \
            podman run \
            --user 0:0 \
            --log-level $_ST_LOG_LEVEL \
            --pod serenditree \
            --name $_CONTAINER \
            --label serenditree.io/service=${_SERVICE} \
            --env-file ./plot.env \
            --env SERENDITREE_BRANCH="$_BRANCH" \
            --env SERENDITREE_SERVICE="$_SERVICE" \
            --env SERENDITREE_VERSION="$_VERSION" \
            --env SERENDITREE_ORDINAL="$_ORDINAL" \
            --env SERENDITREE_STAGE="$_ST_STAGE" \
            --env QUARKUS_HTTP_PORT="$_EXPOSE" \
            --volume ${_VOLUME_SRC_REPO}:${_VOLUME_DST_REPO}:Z \
            --health-cmd "bash health.sh" \
            --health-interval 3s \
            --health-retries 1 \
            --detach

        echo "Adding source from ${_VOLUME_SRC_SRC}..."
        podman cp ${_VOLUME_SRC_SRC}/. ${_CONTAINER}:${_VOLUME_DST_SRC}
        echo "Starting build..."
        podman exec ${_CONTAINER} touch ${_VOLUME_DST_SRC}/release
    elif [[ -n "$_ARG_SETUP" ]]; then
        sc_heading 1 "Setting up branch"

        [[ -z "$_ARG_DRYRUN" ]] && _ST_HELM_NAME=branch
        sc_branch_secrets helm | xargs \
            helm $_ST_HELM_CMD $_ST_HELM_NAME ./charts/cd \
            --set "global.context=$_ST_CONTEXT" \
            --set "branch.jsonWebKey.encryption=$(pass serenditree/json.web.key)" \
            --set "branch.jsonWebKey.signature=$(pass serenditree/json.web.key)" | $_ST_HELM_PIPE

        if [[ -n "$_ARG_DRYRUN" ]]; then
            sc_branch_secrets helm | xargs \
                helm $_ST_HELM_CMD $_ST_HELM_NAME ./charts/app \
                --set "global.context=$_ST_CONTEXT" \
                --set "branch.jsonWebKey.encryption=$(pass serenditree/json.web.key)" \
                --set "branch.jsonWebKey.signature=$(pass serenditree/json.web.key)" | $_ST_HELM_PIPE
        fi

        if [[ -z "$_ARG_DRYRUN" ]]; then
            argocd app sync branch
            argocd app wait branch --health
        fi
    fi
########################################################################################################################
# DOWN
########################################################################################################################
elif [[ " $* " =~ " down " ]] && [[ -n "$_ST_CONTEXT_CLUSTER" ]]; then
    if [[ -n "$_ARG_DELETE" ]]; then
        sc_heading 1 "Deleting ${_SERVICE}"
        argocd app delete --yes branch
        helm uninstall branch
    fi
########################################################################################################################
# TEKTON
########################################################################################################################
elif [[ " $* " =~ ( (tekton|tkn) ) ]]; then
    sc_heading 1 "Running tekton..."
    kubectl create --namespace tekton-pipelines -f ./charts/tkn/resources/run.yml &&
        sleep 1s &&
        tkn pipeline logs --namespace tekton-pipelines --last --follow branch
fi
