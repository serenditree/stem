#!/usr/bin/env bash
########################################################################################################################
# ROOT-WIND
########################################################################################################################
_SERVICE=root-wind
_ORDINAL="17"

_IMAGE=serenditree/$_SERVICE
_VERSION=latest
_TAG=$_VERSION

_CONTAINER=$_SERVICE

_EXPOSE=9092/tcp

_KAFKA_MIRROR=https://archive.apache.org/dist/kafka
_KAFKA_VERSION=2.7.0
_KAFKA_SCALA_VERSION=2.13
_KAFKA_PATH="kafka_${_KAFKA_SCALA_VERSION}-${_KAFKA_VERSION}"
_KAFKA_ARCHIVE="data/kafka-${_KAFKA_SCALA_VERSION}-${_KAFKA_VERSION}.tar.gz"
_KAFKA_PORT=${_EXPOSE%/*}
_KAFKA_TOPICS="seed-created seed-deleted"

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# BUILD
########################################################################################################################
if [[ " $* " =~ " build " ]]; then
    sc_heading 1 "Building ${_IMAGE}:${_TAG}"
    [[ -n "$_ARG_DRYRUN" ]] && exit 0
    _CONTAINER_REF=$(buildah from serenditree/java-base)
    _MOUNT_REF=$(buildah mount $_CONTAINER_REF)

    if [[ ! -f ${_KAFKA_ARCHIVE} ]]; then
        echo "Downloading ${_KAFKA_ARCHIVE}..."
        mkdir -p ${_KAFKA_ARCHIVE%/*}
        curl "${_KAFKA_MIRROR}/${_KAFKA_VERSION}/${_KAFKA_PATH}.tgz" --output ${_KAFKA_ARCHIVE}
    fi
    _KAFKA_PATH="${_ST_CONTAINER_ROOT}/${_KAFKA_PATH}"

    buildah config --workingdir $_ST_CONTAINER_ROOT $_CONTAINER_REF

    buildah add --chown 1000:0 $_CONTAINER_REF ${_KAFKA_ARCHIVE}
    buildah add --chown 1000:0 $_CONTAINER_REF src/

    sed -i 's/=INFO/=WARN/g' ${_MOUNT_REF}/${_KAFKA_PATH}/config/*log4j.properties

    buildah config --env KAFKA_PATH=$_KAFKA_PATH $_CONTAINER_REF
    buildah config --env KAFKA_VERSION=$_KAFKA_VERSION $_CONTAINER_REF
    buildah config --env KAFKA_SCALA_VERSION=$_KAFKA_SCALA_VERSION $_CONTAINER_REF
    buildah config --env KAFKA_PORT=$_KAFKA_PORT $_CONTAINER_REF
    buildah config --env KAFKA_TOPICS="$_KAFKA_TOPICS" $_CONTAINER_REF

    buildah config --port $_EXPOSE $_CONTAINER_REF

    buildah config --cmd "bash wrapper.sh" $_CONTAINER_REF

    buildah umount $_CONTAINER_REF
    sc_image_config_commit "$_SERVICE" "$_IMAGE" "$_VERSION" "$_TAG" "$_ORDINAL" "$_CONTAINER_REF"
########################################################################################################################
# UP
########################################################################################################################
elif [[ " $* " =~ " up " ]]; then
    if [[ -z "$_ST_CONTEXT_CLUSTER" ]]; then
        sc_heading 1 "Starting ${_SERVICE}:${_TAG}"
        sc_container_rm $_CONTAINER

        podman run \
            --log-level $_ST_LOG_LEVEL \
            --pod $_ST_POD \
            --name $_CONTAINER \
            --health-cmd "bash health.sh" \
            --health-interval 3s \
            --health-retries 1 \
            --detach \
            ${_IMAGE}:${_TAG}
    elif [[ -n "$_ARG_SETUP" ]]; then
        sc_heading 1 "Setting up ${_SERVICE}"

        [[ -z "$_ARG_DRYRUN" ]] && _ST_HELM_NAME="$_SERVICE"
        helm $_ST_HELM_CMD $_ST_HELM_NAME ./charts/cd \
            --set "global.context=$_ST_CONTEXT" | $_ST_HELM_PIPE

        if [[ -n "$_ARG_DRYRUN" ]]; then
            helm template ./charts/app --set "global.context=$_ST_CONTEXT" | yq eval
        else
            argocd app sync "$_SERVICE"
            argocd app wait "$_SERVICE" --health
        fi

        echo "Adding root wind service alias..."
        if [[ -z "$_ARG_DRYRUN" ]]; then
            kubectl get svc/root-wind-kafka-bootstrap -o json |
                jq 'del(.metadata, .spec.clusterIP, .spec.clusterIPs)' |
                jq '.metadata.name = "root-wind"' |
                kubectl apply -f -
        fi
    fi
########################################################################################################################
# DOWN
########################################################################################################################
elif [[ " $* " =~ " down " ]] && [[ -n "$_ST_CONTEXT_CLUSTER" ]]; then
    if [[ -z "$_ARG_DRYRUN" ]] && [[ -n "$_ARG_DELETE" ]]; then
        sc_heading 1 "Deleting ${_SERVICE}"
        argocd app delete "$_SERVICE"
        helm uninstall "$_SERVICE"
    fi
fi
