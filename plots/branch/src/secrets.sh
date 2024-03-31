#!/usr/bin/env bash
########################################################################################################################
# BRANCH SECRETS
# Retrieves secrets for injection during command execution.
# $1: Target command {helm|podman}.
########################################################################################################################
_TARGET=$1
_ENV=
_INDEX=0

pass serenditree/oidc | sed -En 's/.*(\w{2}\.\w+)/\1/p' | while read -r _ITEM; do
    _COUNTRY="${_ITEM%.*}"

    if [[ "$_TARGET" == "helm" ]]; then
        if [[ "${_ITEM#*.}" == "id" ]]; then
            echo -n "--set \"branch.oidc[${_INDEX}].country=${_COUNTRY}\" "
            echo -n "--set \"branch.oidc[${_INDEX}].id=$(pass serenditree/oidc/${_ITEM})\" "
            echo -n "--set \"branch.oidc[${_INDEX}].idRef=oidc-id-${_COUNTRY}\" "
        elif [[ "${_ITEM#*.}" == "secret" ]]; then
            echo -n "--set \"branch.oidc[${_INDEX}].secret=$(pass serenditree/oidc/${_ITEM})\" "
            echo -n "--set \"branch.oidc[${_INDEX}].secretRef=oidc-secret-${_COUNTRY}\" "
        else
            echo -n "--set \"branch.oidc[${_INDEX}].url=$(pass serenditree/oidc/${_ITEM})\" "
            echo -n "--set \"branch.oidc[${_INDEX}].urlRef=oidc-url-${_COUNTRY}\" "
            ((_INDEX++))
        fi
    elif [[ "$_TARGET" == "podman" ]]; then
        # podman or podman-compose
        _COUNTRY="${_COUNTRY^^}"
        if [[ "${_ITEM#*.}" == "id" ]]; then
            _ENV="QUARKUS_OIDC_${_COUNTRY}_CLIENT_ID"
        elif [[ "${_ITEM#*.}" == "secret" ]]; then
            _ENV="QUARKUS_OIDC_${_COUNTRY}_CREDENTIALS_SECRET"
        else
            echo -n "--env QUARKUS_OIDC_${_COUNTRY}_APPLICATION_TYPE=web-app "
            _ENV="QUARKUS_OIDC_${_COUNTRY}_AUTH_SERVER_URL"
        fi
        echo -n "--env ${_ENV}=$(pass serenditree/oidc/${_ITEM}) "
    else
        echo "Invalid target '${_TARGET}'"
        exit 1
    fi
done
