#!/usr/bin/env bash
########################################################################################################################
# LOGIN
# Authenticates and checks authentication.
########################################################################################################################

# Checks registry authentication using podman.
# $1: Registry to check (for example quay.io)
function sc_logged_in() {
    podman login --get-login $1 >/dev/null 2>&1
}
export -f sc_logged_in

# Authenticate at the given service.
# $1: Service that needs authentication.
function sc_login() {
    case $1 in
    redhat)
        local -r _registry=registry.redhat.io
        local -r _credentials=$(pass serenditree/$_registry)
        { sc_logged_in $_registry && echo 'Already logged in.'; } || podman login \
            -u "${_credentials%%:*}" \
            -p "${_credentials#*:}" \
            "$_registry"
        ;;
    quay)
        local -r _registry=quay.io
        local -r _credentials=$(pass serenditree/$_registry)
        { sc_logged_in $_registry && echo 'Already logged in.'; } || podman login \
            -u "${_credentials%%:*}" \
            -p "${_credentials#*:}" \
            "$_registry"
        ;;
    argo*)
        local -r _argocd_password="$(pass serenditree/argocd)"
        sc_cluster_expose argocd
        sleep 1s
        argocd login localhost:9098 --insecure --username admin --password "$_argocd_password"
        ;;
    openshift)
        echo "Requesting token..."
        xdg-open "$_ST_CLUSTER_OAUTH" >/dev/null 2>&1
        read -rp "Token: " _token
        echo "Logging in to openshift online..."
        [[ -n "$_token" ]] && oc login --token="$_token" "$_ST_CLUSTER"
        sc_login quay
        ;;
    openshift/local)
        echo "Logging in to crc..."
        if [[ -n "$_ST_CONTEXT_TKN" ]]; then
            local -r _credentials="${_ST_OPENSHIFT_USERNAME}:${_ST_OPENSHIFT_PASSWORD}"
        else
            local -r _credentials=$(pass serenditree/crc.testing)
        fi
        oc login --insecure-skip-tls-verify \
            -u "${_credentials%%:*}" \
            -p "${_credentials#*:}" \
            "$_ST_CLUSTER"
        oc registry login --skip-check
        ;;
    esac
}
export -f sc_login

# Opens a database console
# $1: local or cluster context
# $2: database
function sc_login_db() {
    local -r _ctx=$1
    local -r _db=$2

    case $_db in
    user | maria)
        if [[ "$_ctx" == "cluster" ]]; then
            local -r _credentials=$(pass serenditree/root.user)
            kubectl port-forward svc/root-user 3306:3306 &
            sleep 1s
            mysql -u"${_credentials%%:*}" -p"${_credentials#*:}" --protocol=TCP serenditree
            killall kubectl && echo "Port-forwarding stopped"
        else
            mysql -uuser -puser --port=8085 --protocol=TCP serenditree
        fi
        ;;
    seed | mongo)
        if [[ "$_ctx" == "cluster" ]]; then
            local -r _credentials=$(pass serenditree/root.seed)
            kubectl port-forward pod/root-seed-0 27017:27017 &
            sleep 1s
            mongo -u"${_credentials%%:*}" -p"${_credentials#*:}" serenditree
            killall kubectl && echo "Port-forwarding stopped"
        else
            mongo -uuser -puser --port=8086 serenditree
        fi
        ;;
    esac
}
