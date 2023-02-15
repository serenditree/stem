#!/usr/bin/env bash
########################################################################################################################
# KUBERNETES LOCAL
# Installs, upgrades, configures and resets minishift.
########################################################################################################################

function sc_kubernetes_local_up() {
    minikube start --profile "$_ST_CONTEXT_KUBERNETES_LOCAL" \
        --namespace serenditree \
        --addons dashboard \
        --addons metrics-server \
        --addons ingress 2>&1 | sed '/#8426/d'

    local -r _ip="$(minikube ip --profile "$_ST_CONTEXT_KUBERNETES_LOCAL")"
    sudo sed -i '/serenditree.io/d' /etc/hosts
    echo "$_ip serenditree.io" | sudo tee -a /etc/hosts

    if [[ -n "$_ARG_DASHBOARD" ]]; then
        sc_cluster_dashboard
    fi
}

function sc_kubernetes_local_down() {
    if minikube status --profile "$_ST_CONTEXT_KUBERNETES_LOCAL" | grep -Eq "Stopped|not found"; then
        echo "Nothing to shut down."
    else
        until minikube stop --profile "$_ST_CONTEXT_KUBERNETES_LOCAL" --keep-context-active; do :; done
        sudo sed -i '/serenditree.io/d' /etc/hosts
        killall kubectl &>/dev/null
    fi
}

function sc_kubernetes_local_reset() {
    sc_heading 2 "Deleting profile..."
    minikube delete --profile "$_ST_CONTEXT"
    sc_heading 2 "Removing network..."
    sudo podman network rm minikube "$_ST_CONTEXT"
    sc_heading 2 "Resetting context..."
    sc_context_init
}
