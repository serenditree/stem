#!/usr/bin/env bash
########################################################################################################################
# LEAF
########################################################################################################################
_SERVICE=leaf
_ORDINAL=14

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
    _CONTAINER_REF=$(buildah from ${_QUALIFIED}serenditree/nginx)
    _MOUNT_REF=$(buildah mount $_CONTAINER_REF)

    if [[ "$_CONFIG" == "compose" ]]; then
        echo "Installing curl..."
        dnf install --installroot ${_MOUNT_REF:?} $_ST_DNF_OPTS_HOST curl
        dnf clean all --installroot ${_MOUNT_REF:?} --noplugins
        echo "Disabling otel..."
        buildah config --env OTEL_ENABLED="off" $_CONTAINER_REF
    fi

    echo "Adding application..."
    buildah add --chown 1001:0 $_CONTAINER_REF ${_VOLUME_SRC}/dist/browser ${_ST_CONTAINER_ROOT}/html

    buildah config --env DESCRIPTION="$_DESCRIPTION" $_CONTAINER_REF
    buildah config --label description="$_DESCRIPTION" $_CONTAINER_REF

    buildah rm $_CONTAINER_REF_1
    buildah umount $_CONTAINER_REF
    sc_image_config_commit "$_SERVICE" "$_IMAGE" "$_VERSION" "$_TAG" "$_ORDINAL" "$_CONTAINER_REF"
########################################################################################################################
# UP
########################################################################################################################
elif [[ " $* " =~ " up " ]] && [[ -z "$_ST_CONTEXT_CLUSTER" ]]; then
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
########################################################################################################################
# TEKTON
########################################################################################################################
elif [[ " $* " =~ ( (tkn|tekton) ) ]]; then
    sc_heading 1 "Running tekton..."
    kubectl create --namespace terra-tekton -f ./rc/run.yml &&
        sleep 1s &&
        tkn pipeline logs --namespace terra-tekton --last --follow leaf
fi
