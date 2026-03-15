#!/usr/bin/env bash
########################################################################################################################
# TESTING
########################################################################################################################
_SERVICE=testing
_ORDINAL=6

_IMAGE=serenditree/$_SERVICE
_VERSION=latest
_TAG=$_VERSION

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# BUILD
########################################################################################################################
if [[ " $* " =~ " build " ]]; then
    sc_heading 1 "Building ${_IMAGE}:${_TAG}"
    [[ -n "$_ARG_DRYRUN" ]] && exit 0
    _DESCRIPTION="Custom k6 image for testing with faker extension."
    _BUILDAH_ARGS="--ulimit nofile=$(ulimit -n) "
    ####################################################################################################################
    # STEP BUILDER
    ####################################################################################################################
    _BUILD_CONTAINER_REF=$(buildah from $_BUILDAH_ARGS docker.io/golang:1.23)
    _BUILD_MOUNT_REF=$(buildah mount $_BUILD_CONTAINER_REF)

    sc_heading 2 "Building k6 with faker extension..."
    buildah run $_BUILD_CONTAINER_REF -- go install go.k6.io/xk6/cmd/xk6@latest
    buildah run $_BUILD_CONTAINER_REF -- \
        xk6 build \
            --with github.com/grafana/xk6-faker@latest \
            --output /k6
    ####################################################################################################################
    # STEP PACKAGE
    ####################################################################################################################
    _CONTAINER_REF=$(buildah from $_BUILDAH_ARGS docker.io/grafana/k6:latest)

    sc_heading 2 "Adding artifact to test-image..."
    buildah add --chown 1001:0 $_CONTAINER_REF ${_BUILD_MOUNT_REF:?}/k6 /usr/bin/k6
    # cp ${_BUILD_MOUNT_REF:?}/k6 .

    buildah config \
        --env DESCRIPTION="$_DESCRIPTION" \
        --label description="$_DESCRIPTION" \
        --user 1001:0 \
        $_CONTAINER_REF

    buildah umount $_BUILD_CONTAINER_REF
    buildah rm $_BUILD_CONTAINER_REF
    sc_image_config_commit "$_SERVICE" "$_IMAGE" "$_VERSION" "$_TAG" "$_ORDINAL" "$_CONTAINER_REF"
fi
