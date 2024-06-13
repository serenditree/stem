#!/usr/bin/env bash
########################################################################################################################
# ROOT-USER
########################################################################################################################
_SERVICE=root-user
_ORDINAL="14"

_IMAGE=serenditree/root-user
_VERSION=latest
_TAG=$_VERSION

_CONTAINER=$_SERVICE

_VOLUME_SRC=root-user
_VOLUME_DST=/bitnami/mariadb

_EXPOSE=3306/tcp

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# BUILD
########################################################################################################################
if [[ " $* " =~ " build " ]]; then
    sc_heading 1 "Building ${_IMAGE}:${_TAG}"
    [[ -n "$_ARG_DRYRUN" ]] && exit 0
    _CONTAINER_REF=$(buildah from $_ST_FROM_ROOT_USER)

    buildah add --chown 1001:0 $_CONTAINER_REF ./charts/app/resources/0.0.1-init.sql /docker-entrypoint-initdb.d/

    buildah config --volume $_VOLUME_DST $_CONTAINER_REF
    buildah config --port $_EXPOSE $_CONTAINER_REF

    sc_env_rm $_CONTAINER_REF
    sc_label_rm $_ST_FROM_ROOT_USER $_CONTAINER_REF
    sc_image_config_commit "$_SERVICE" "$_IMAGE" "$_VERSION" "$_TAG" "$_ORDINAL" "$_CONTAINER_REF"
########################################################################################################################
# UP
########################################################################################################################
elif [[ " $* " =~ " up " ]]; then
    if [[ -z "$_ST_CONTEXT_CLUSTER" ]]; then
        sc_heading 1 "Starting ${_SERVICE}:${_TAG}"
        sc_container_rm $_CONTAINER

        # shellcheck disable=SC2046
        podman run \
            --log-level $_ST_LOG_LEVEL \
            --pod $_ST_POD \
            --name $_CONTAINER \
            --env-file ./plot.env \
            $([[ -z "$_ARG_INTEGRATION" ]] && echo --volume ${_VOLUME_SRC}:${_VOLUME_DST}:Z) \
            --health-cmd 'mysqladmin status -uroot -p"${MARIADB_ROOT_PASSWORD}"' \
            --health-interval 3s \
            --health-retries 1 \
            --detach \
            ${_IMAGE}:${_TAG}
    elif [[ -n "$_ARG_SETUP" ]]; then
        sc_heading 1 "Setting up ${_SERVICE}"

        _cluster_domain=$(sc_context_cluster_domain)
        _credentials=$(pass serenditree/root.user)
        _credentials_root="$(pass serenditree/root.user.root)"

        [[ -z "$_ARG_DRYRUN" ]] && _ST_HELM_NAME=root-user
        helm $_ST_HELM_CMD $_ST_HELM_NAME ./charts/cd \
            --set "global.context=$_ST_CONTEXT" \
            --set "clusterDomain=$_cluster_domain" \
            --set "db.user=${_credentials%%:*}" \
            --set "db.password=${_credentials#*:}" \
            --set "rootUser.password=$_credentials_root" | $_ST_HELM_PIPE

        if [[ -z "$_ARG_DRYRUN" ]]; then
            argocd app sync root-user
            argocd app set root-user --parameter rootUser.mariadb=true
            argocd app sync root-user
            argocd app wait root-user --health
        fi
    fi
fi
