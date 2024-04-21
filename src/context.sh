#!/usr/bin/env bash
########################################################################################################################
# CONTEXT
# Define and use serenditree contexts.
########################################################################################################################

# Returns the kubernetes cluster domain depending on the current context.
function sc_context_cluster_domain() {
    if [[ -z "${_ST_CONTEXT_IS_LOCAL}${_ST_CONTEXT_TKN}" ]]; then
        echo "$(yq eval '.current-context' ~/.kube/config.sks).cluster.local"
    else
        echo "cluster.local"
    fi
}
export -f sc_context_cluster_domain

# Initializes or resets available contexts.
function sc_context_init_generic() {
    local -r _from=$1
    local -r _to=$2
    kubectl config get-contexts "$_to" &>/dev/null && kubectl config delete-context "$_to"
    kubectl config rename-context "$_from" "$_to"
    kubectl config set-context "$_to"
    kubectl create namespace serenditree
    kubectl config set-context --current --namespace=serenditree
}
export -f sc_context_init_generic

# Initializes the context of the remote kubernetes cluster.
function sc_context_init_kube() {
    echo "Fetching kubeconfig..."
    local -r _config=~/.kube/config.sks
    local -r _ttl="$((60 * 60 * 24 * 90))"
    local -r _group="system:masters"
    until exo compute sks kubeconfig serenditree kube-admin --ttl $_ttl --group $_group  --zone at-vie-1 >$_config
    do
        sleep 1s
    done
    local -r _sks_id="$(sed -En 's/.*current-context: (.*)/\1/p' $_config)"
    # shellcheck disable=SC2155,SC2011
    export KUBECONFIG="$(ls ~/.kube/config* | xargs echo | tr ' ' ':')"
    sc_context_init_generic "$_sks_id" "$_ST_CONTEXT_KUBERNETES"
    echo  "Waiting for nodes..."
    until kubectl wait --for=condition=ready --all-namespaces --all nodes 2>/dev/null; do sleep 1s; done
}
export -f sc_context_init_kube

# Initializes available contexts.
function sc_context_init() {
    for _context in "${_ST_CONTEXTS[@]}"; do
        if ! kubectl config get-contexts $_context &>/dev/null; then
            kubectl config set-context $_context --cluster no-cluster --user no-user --namespace serenditree
        fi
    done

    if [[ -n "$_ARG_SETUP" ]]; then
        if [[ -n "$_ST_CONTEXT_KUBERNETES" ]]; then
            sc_context_init_kube
        elif [[ -n "$_ST_CONTEXT_KUBERNETES_LOCAL" ]]; then
            sc_context_init_generic minikube "$_ST_CONTEXT_KUBERNETES_LOCAL"
        elif [[ -n "$_ST_CONTEXT_OPENSHIFT_LOCAL" ]]; then
            oc login -u kubeadmin -p crc.testing https://api.crc.testing:6443
            sc_context_init_generic default/api-crc-testing:6443/kubeadmin "$_ST_CONTEXT_OPENSHIFT_LOCAL"
        fi
    fi
}
export -f sc_context_init

# Selects a context.
# $1: Pattern or index for context selection
function sc_context_use() {
    if [[ $1 =~ [[:digit:]] ]]; then
        local -r _pattern=serenditree
        local -r _index=$1
    else
        local -r _pattern=$1
        local -r _index=1
    fi
    kubectl config get-contexts --no-headers |
        grep -E "$_pattern" |
        sed -En -e 's/[* ]+(\S+).*/\1/' -e "${_index}p" |
        xargs -I{} bash -c "[[ \"$(kubectl config current-context)\" != \"{}\" ]] && kubectl config use-context {}"
}
export -f sc_context_use

# Shows and/or sets the cluster context.
# $1: Optional ID (unpadded number) of the context to set.
function sc_context() {
    if [[ -n "${_ARG_INIT}" ]]; then
        sc_context_init
    fi
    # Set context!
    if [[ -n "$1" ]]; then
        sc_context_use "$1"
    elif [[ $_ST_CONTEXT =~ ^serenditree ]]; then
        sc_context_use "[[:space:]]${_ST_CONTEXT}[[:space:]]"
    fi
    # Show contexts!
    kubectl config get-contexts --no-headers |
        grep -E "serenditree" |
        sed -E 's/([* ]+\S+).*/\1/' |
        nl -w2 -s' ' -n'rz'

    local _authenticated=1
    sc_cluster_status && _authenticated=0

    return $_authenticated
}
export -f sc_context
