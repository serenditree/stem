#!/usr/bin/env bash
########################################################################################################################
# BUILDAH
########################################################################################################################
_SERVICE=soil-buildah
_ORDINAL=13

_IMAGE=serenditree/buildah
_VERSION=latest
_TAG=$_VERSION

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# BUILD
########################################################################################################################
if [[ " $* " =~ " build " ]]; then
    sc_heading 1 "Building buildah:${_TAG}"
    [[ -n "$_ARG_DRYRUN" ]] && exit 0

    _DESCRIPTION="Buildah image including findutils and jq."
    _CONTAINER_REF=$(buildah from quay.io/buildah/stable)

    sc_distro_sync dnf $_CONTAINER_REF

    buildah run $_CONTAINER_REF -- dnf install findutils jq $_ST_DNF_OPTS
    buildah run $_CONTAINER_REF -- dnf clean all

    buildah config --env DESCRIPTION="$_DESCRIPTION" $_CONTAINER_REF
    buildah config --label description="$_DESCRIPTION" $_CONTAINER_REF

    sc_image_commit "$_IMAGE" "$_TAG" "$_CONTAINER_REF"
fi
