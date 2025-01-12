#!/usr/bin/env bash
########################################################################################################################
# ROOT-SEED
########################################################################################################################
_SERVICE=root-seed
_ORDINAL=7

_IMAGE=serenditree/root-seed
_VERSION=latest
_TAG=$_VERSION

_CONTAINER=$_SERVICE

_VOLUME_SRC=root-seed
_VOLUME_DST=/bitnami/mongodb

_EXPOSE=27017/tcp

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# BUILD
########################################################################################################################
if [[ " $* " =~ " build " ]]; then
    sc_heading 1 "Building ${_IMAGE}:${_TAG}"
    [[ -n "$_ARG_DRYRUN" ]] && exit 0
    _CONTAINER_REF=$(buildah from $_ST_FROM_ROOT_SEED)

    buildah add --chown 1001:0 $_CONTAINER_REF ./charts/app/resources/0.0.1-init.js /docker-entrypoint-initdb.d/

    buildah config --volume $_VOLUME_DST $_CONTAINER_REF
    buildah config --port $_EXPOSE $_CONTAINER_REF

    sc_env_rm $_CONTAINER_REF
    sc_label_rm $_ST_FROM_ROOT_SEED $_CONTAINER_REF
    sc_image_config_commit "$_SERVICE" "$_IMAGE" "$_VERSION" "$_TAG" "$_ORDINAL" "$_CONTAINER_REF"
########################################################################################################################
# UP
########################################################################################################################
elif [[ " $* " =~ " up " ]] && [[ -z "$_ST_CONTEXT_CLUSTER" ]]; then
    sc_heading 1 "Starting ${_SERVICE}:${_TAG}"
    sc_container_rm $_CONTAINER

    # shellcheck disable=SC2046
    podman run \
        --log-level $_ST_LOG_LEVEL \
        --pod $_ST_POD \
        --name $_CONTAINER \
        --env-file ./plot.env \
        $([[ -z "$_ARG_INTEGRATION" ]] && echo --volume ${_VOLUME_SRC}:${_VOLUME_DST}:Z) \
        --health-cmd "mongosh --port 27017 --eval \"db.adminCommand('ping')\"" \
        --health-interval 3s \
        --health-retries 1 \
        --ulimit nproc=64000 \
        --ulimit nofile=64000 \
        --detach \
        ${_IMAGE}:${_TAG}
fi
