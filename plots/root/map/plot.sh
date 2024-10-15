#!/usr/bin/env bash
########################################################################################################################
# ROOT-MAP
########################################################################################################################
_SERVICE=root-map
_ORDINAL=17

_IMAGE=serenditree/root-map
_VERSION=latest
_TAG=$_VERSION

_CONTAINER=$_SERVICE

_VOLUME_SRC="$(dirname "$(realpath $0)")/data/database"
_VOLUME_DST=${_ST_CONTAINER_ROOT}/data

_EXPOSE=8080/tcp
_EXPOSE_LOCAL=8084/tcp

_TILESERVER_VERSION=4.10.3
_TILESERVER_PORT=${_EXPOSE%/*}
# TODO check versions (compatibility with mbtiles)
_STYLES_VERSION=v1.8
_FONTS_VERSION=v2.0

_BASE_URL=https://github.com/openmaptiles
_STYLES_URL=${_BASE_URL}/positron-gl-style/releases/download/${_STYLES_VERSION}/${_STYLES_VERSION}.zip
_FONTS_URL=${_BASE_URL}/fonts/releases/download/${_FONTS_VERSION}/${_FONTS_VERSION}.zip

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# BUILD
########################################################################################################################
if [[ " $* " =~ " build " ]]; then
    sc_heading 1 "Building ${_IMAGE}:${_TAG}"
    [[ -n "$_ARG_DRYRUN" ]] && exit 0
    _DESCRIPTION="Production image for root-map."

    _CONTAINER_REF=$(buildah from serenditree/node-base)
    _MOUNT_REF=$(buildah mount $_CONTAINER_REF)

    _SERVER_DIR="./data/server"
    if [[ ! -d $_SERVER_DIR  ]]; then
        mkdir -pv ${_SERVER_DIR}/styles/positron ${_SERVER_DIR}/fonts ${_SERVER_DIR}/data
        pushd $_SERVER_DIR >/dev/null || exit 1
        echo "Downloading styles ${_STYLES_VERSION}..."
        curl -L $_STYLES_URL -o styles/positron/${_STYLES_VERSION}.zip
        unzip -q styles/positron/${_STYLES_VERSION}.zip -d styles/positron && rm styles/positron/${_STYLES_VERSION}.zip
        echo "Downloading fonts ${_FONTS_VERSION}..."
        curl -L $_FONTS_URL -o fonts/${_FONTS_VERSION}.zip
        unzip -q fonts/${_FONTS_VERSION}.zip -d fonts && rm fonts/${_FONTS_VERSION}.zip

        echo "Installing tileserver ${_TILESERVER_VERSION}..."
        yarn add tileserver-gl-light@${_TILESERVER_VERSION}
        ln -s ./node_modules/.bin/tileserver-gl-light tileserver-gl-light
        popd >/dev/null || exit 1
    else
        echo "Using existing data..."
    fi

    echo "Adding script..."
    buildah add --chown 1001:0 $_CONTAINER_REF ./src
    echo "Adding server..."
    buildah add --chown 1001:0 $_CONTAINER_REF $_SERVER_DIR

    buildah run $_CONTAINER_REF -- chown -R 1001:0 $_ST_CONTAINER_ROOT
    buildah run $_CONTAINER_REF -- chmod -R g=u $_ST_CONTAINER_ROOT

    buildah config --label description="$_DESCRIPTION" $_CONTAINER_REF

    buildah config --env DESCRIPTION="$_DESCRIPTION" $_CONTAINER_REF
    buildah config --env TILESERVER_VERSION=$_TILESERVER_VERSION $_CONTAINER_REF
    buildah config --env TILESERVER_PORT=$_TILESERVER_PORT $_CONTAINER_REF

    buildah config --user 1001:0 $_CONTAINER_REF
    buildah config --volume $_VOLUME_DST $_CONTAINER_REF
    buildah config --port $_EXPOSE $_CONTAINER_REF
    buildah config --port $_EXPOSE_LOCAL $_CONTAINER_REF

    buildah config --cmd "bash wrapper.sh" $_CONTAINER_REF

    rm -rf ${_MOUNT_REF:?}/var/cache/*
    buildah umount $_CONTAINER_REF

    sc_image_config_commit "$_SERVICE" "$_IMAGE" "$_VERSION" "$_TAG" "$_ORDINAL" "$_CONTAINER_REF"
########################################################################################################################
# UP
########################################################################################################################
elif [[ " $* " =~ " up " ]]; then
    if  [[ -z "$_ST_CONTEXT_CLUSTER" ]]; then
        sc_heading 1 "Starting ${_SERVICE}:${_TAG}"
        sc_container_rm $_CONTAINER

        if [[ ! -f ${_VOLUME_SRC}/osm.mbtiles ]]; then
            echo "Database osm.mbtiles does not exist. Aborting..."
            exit 1
        fi

        podman run \
            --log-level $_ST_LOG_LEVEL \
            --pod $_ST_POD \
            --name $_CONTAINER \
            --env TILESERVER_PORT=${_EXPOSE_LOCAL%/*} \
            --volume ${_VOLUME_SRC}:${_VOLUME_DST}:Z \
            --health-cmd "curl --silent localhost:${_EXPOSE_LOCAL%/*}/index.json" \
            --health-interval 3s \
            --health-retries 1 \
            --detach \
            ${_IMAGE}:${_TAG}
########################################################################################################################
# SETUP
########################################################################################################################
    elif [[ -n "$_ARG_SETUP" ]]; then
        sc_heading 1 "Setting up ${_SERVICE}"

        if [[ -z "$_ARG_DRYRUN" ]]; then
            _ST_HELM_NAME=root-map
            kubectl create secret generic exoscale-data \
                --from-literal="apikey=$(pass serenditree/data@exoscale.com.access)" \
                --from-literal="secret=$(pass serenditree/data@exoscale.com.secret)" \
                --namespace serenditree
        fi
        helm $_ST_HELM_CMD $_ST_HELM_NAME ./charts/cd \
            --set "global.context=$_ST_CONTEXT" \
            --set "ingress.letsencrypt.issuer=$_ARG_ISSUER" \
            --set "rootMap.host=$_ST_DOMAIN" \
            --set "rootMap.dataMountPath=$_VOLUME_DST" \
            --set "rootMap.stage=$_ST_STAGE" | $_ST_HELM_PIPE

        if [[ -z "$_ARG_DRYRUN" ]]; then
            argocd app sync root-map
            argocd app wait root-map --health
        else
            helm $_ST_HELM_CMD $_ST_HELM_NAME ./charts/app \
                --set "global.context=$_ST_CONTEXT" \
                --set "ingress.letsencrypt.issuer=$_ARG_ISSUER" \
                --set "rootMap.host=$_ST_DOMAIN" \
                --set "rootMap.dataMountPath=$_VOLUME_DST" \
                --set "rootMap.stage=$_ST_STAGE" | $_ST_HELM_PIPE
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
