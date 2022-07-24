#!/usr/bin/env bash

# Retrieves secrets for injection during command execution.
# $1: Target command {helm|podman}.
function sc_branch_secrets() {
    local _target=$1
    local _env=
    local _index=0

    pass serenditree/oidc | sed -En 's/.*(\w{2}\.\w+)/\1/p' | while read -r _item; do
        _country="${_item%.*}"

        if [[ "$_target" == "helm" ]]; then
            if [[ "${_item#*.}" == "id" ]]; then
                echo -n "--set \"branch.oidc[${_index}].country=${_country}\" "
                echo -n "--set \"branch.oidc[${_index}].id=$(pass serenditree/oidc/${_item})\" "
                echo -n "--set \"branch.oidc[${_index}].idRef=oidc-id-${_country}\" "
            elif [[ "${_item#*.}" == "secret" ]]; then
                echo -n "--set \"branch.oidc[${_index}].secret=$(pass serenditree/oidc/${_item})\" "
                echo -n "--set \"branch.oidc[${_index}].secretRef=oidc-secret-${_country}\" "
            else
                echo -n "--set \"branch.oidc[${_index}].url=$(pass serenditree/oidc/${_item})\" "
                echo -n "--set \"branch.oidc[${_index}].urlRef=oidc-url-${_country}\" "
                ((_index++))
            fi
        elif [[ "$_target" == "podman" ]]; then
            # podman or podman-compose
            _country="${_country^^}"
            if [[ "${_item#*.}" == "id" ]]; then
                _env="QUARKUS_OIDC_${_country}_CLIENT_ID"
            elif [[ "${_item#*.}" == "secret" ]]; then
                _env="QUARKUS_OIDC_${_country}_CREDENTIALS_SECRET"
            else
                echo -n "--env QUARKUS_OIDC_${_country}_APPLICATION_TYPE=web-app "
                _env="QUARKUS_OIDC_${_country}_AUTH_SERVER_URL"
            fi
            echo -n "--env ${_env}=$(pass serenditree/oidc/${_item}) "
        else
            echo "Unknown target '$_target'"
            exit 1
        fi
    done
}
export -f sc_branch_secrets
