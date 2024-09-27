#!/usr/bin/env bash
_FLAVOR=$1
_OFFSET=$2
########################################################################################################################
# NODE
########################################################################################################################
_SERVICE=soil-node-${_FLAVOR}
_ORDINAL=$((_OFFSET + 11))

_IMAGE=serenditree/node-${_FLAVOR}
_TAG=latest

_VOLUME_DST=${_ST_CONTAINER_ROOT}/src

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0):${_FLAVOR}:${_OFFSET}"
fi
########################################################################################################################
# BUILD
########################################################################################################################
if [[ " $* " =~ " build " ]]; then
    sc_heading 1 "Building ${_IMAGE}:${_TAG}"
    [[ -n "$_ARG_DRYRUN" ]] && exit 0

    if [[ "$_FLAVOR" == "base" ]]; then
        _DESCRIPTION="Node base image including curl."

        _CONTAINER_REF=$(buildah from scratch)
        _MOUNT_REF=$(buildah mount $_CONTAINER_REF)

        dnf install --installroot ${_MOUNT_REF:?} $_ST_DNF_OPTS_HOST nodejs curl ca-certificates
        dnf clean all --installroot ${_MOUNT_REF:?} --noplugins

        buildah run $_CONTAINER_REF -- mkdir -pv $_ST_CONTAINER_ROOT

        buildah config --workingdir $_ST_CONTAINER_ROOT $_CONTAINER_REF

        buildah config --label description="$_DESCRIPTION" $_CONTAINER_REF

        buildah config --env SERENDITREE_LOG_LEVEL=INFO $_CONTAINER_REF
        buildah config --env DESCRIPTION="$_DESCRIPTION" $_CONTAINER_REF
        buildah config --env LANG="en_US.UTF-8" $_CONTAINER_REF
        buildah config --env LANGUAGE="en_US:en" $_CONTAINER_REF
        buildah config --env NODE_VERSION="$_ST_VERSION_NODE" $_CONTAINER_REF
    elif [[ "$_FLAVOR" == "builder" ]]; then
        _DESCRIPTION="Node builder image including curl."

        _CONTAINER_REF=$(buildah from serenditree/node-base)
        _MOUNT_REF=$(buildah mount $_CONTAINER_REF)

        dnf install --installroot ${_MOUNT_REF:?} $_ST_DNF_OPTS_HOST yarnpkg
        dnf clean all --installroot ${_MOUNT_REF:?} --noplugins

        buildah run $_CONTAINER_REF -- yarn global add @angular/cli@${_ST_VERSION_ANGULAR} sass-migrator
        buildah run $_CONTAINER_REF -- mkdir -pv $_VOLUME_DST

        # buildah config --volume $_VOLUME_DST $_CONTAINER_REF
        buildah config --workingdir $_VOLUME_DST $_CONTAINER_REF

        buildah config --label description="$_DESCRIPTION" $_CONTAINER_REF

        buildah config --env SERENDITREE_LOG_LEVEL=DEBUG $_CONTAINER_REF
        buildah config --env DESCRIPTION="$_DESCRIPTION" $_CONTAINER_REF
        buildah config --env YARN_CACHE="$(buildah run $_CONTAINER_REF yarn cache dir)" $_CONTAINER_REF
    fi

    buildah umount $_CONTAINER_REF
    sc_image_commit "$_IMAGE" "$_TAG" "$_CONTAINER_REF"
fi
