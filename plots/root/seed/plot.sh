#!/usr/bin/env bash
########################################################################################################################
# ROOT-SEED
########################################################################################################################
_SERVICE=root-seed
_ORDINAL="13"

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
elif [[ " $* " =~ " up " ]]; then
    if  [[ -z "$_ST_CONTEXT_CLUSTER" ]]; then
        sc_heading 1 "Starting ${_SERVICE}:${_TAG}"
        sc_container_rm $_CONTAINER

        podman run \
            --log-level $_ST_LOG_LEVEL \
            --pod serenditree \
            --name $_CONTAINER \
            --env-file ./plot.env \
            --volume ${_VOLUME_SRC}:${_VOLUME_DST}:Z \
            --health-cmd "mongo --disableImplicitSessions --eval 'db.hello().isWritablePrimary' | grep -q true" \
            --health-interval 3s \
            --health-retries 1 \
            --ulimit nproc=64000 \
            --ulimit nofile=64000 \
            --detach \
            ${_IMAGE}:${_TAG}
    elif [[ -n "$_ARG_SETUP" ]]; then
        sc_heading 1 "Setting up ${_SERVICE}"
        #helm dependency update rc

        _CREDENTIALS=$(pass serenditree/root.seed)
        _CREDENTIALS_ROOT=$(pass serenditree/root.seed.root)

        [[ -z "$_ARG_DRYRUN" ]] && _ST_HELM_NAME=root-seed
        helm $_ST_HELM_CMD $_ST_HELM_NAME ./charts/cd \
            --set "global.context=$_ST_CONTEXT" \
            --set "clusterDomain=$_ST_CLUSTER_DOMAIN" \
            --set "auth.usernames=${_CREDENTIALS%%:*}" \
            --set "auth.passwords=${_CREDENTIALS#*:}" \
            --set "auth.rootPassword=$_CREDENTIALS_ROOT" | $_ST_HELM_PIPE

        if [[ -z "$_ARG_DRYRUN" ]]; then
            argocd app sync root-seed
            argocd app set root-seed --parameter rootSeed.mongodb=true
            argocd app sync root-seed
            argocd app wait root-seed --health
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
fi
