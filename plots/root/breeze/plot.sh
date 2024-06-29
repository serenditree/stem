#!/usr/bin/env bash
########################################################################################################################
# ROOT-BREEZE
########################################################################################################################
_SERVICE=root-breeze
_ORDINAL=19

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
    _CONTAINER_REF=$(buildah from $_ST_FROM_ROOT_BREEZE)

    buildah run --user 0:0 $_CONTAINER_REF -- gem install fluent-plugin-elasticsearch --no-document
    buildah run --user 0:0 $_CONTAINER_REF -- gem install fluent-plugin-input-gelf --no-document
    buildah config --user 1001:0 $_CONTAINER_REF

    buildah add --chown 1001:0 $_CONTAINER_REF ./fluentd.conf /opt/bitnami/fluentd/conf/

    sc_image_config_commit "$_SERVICE" "$_IMAGE" "$_VERSION" "$_TAG" "$_ORDINAL" "$_CONTAINER_REF"
fi
