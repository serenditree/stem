#!/usr/bin/env bash
########################################################################################################################
# CONTEXT
# Define and use serenditree contexts.
########################################################################################################################

# Returns the kubernetes cluster domain.
function sc_context_cluster_domain() {
    if kubectl version &>/dev/null; then
        kubectl get cm coredns \
            --namespace kube-system \
            --output=jsonpath="{.data.Corefile}" |
            sed -rn 's/.*kubernetes ([^ ]+) .*/\1/p'
    else
        echo "unavailable"
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

# Fetches and sets the context of the remote kubernetes cluster.
function sc_context_init_kube() {
    echo "Fetching kubeconfig..."
    local -r _config=${KUBECONFIG}.sks
    local -r _ttl="$((60 * 60 * 24 * 90))"
    local -r _group="system:masters"
    until exo compute sks kubeconfig serenditree kubeadmin/serenditree \
        --ttl $_ttl \
        --group $_group  \
        --zone "${_ST_ZONE}" >"$_config"
    do
        sleep 1s
    done
    cp -v "$KUBECONFIG" "${KUBECONFIG}.bak"
    local -r _context_sks="$(sed -En 's/.*current-context: (.*)/\1/p' "$_config")"
    sed -i '/current-context/d' "$_config"
    KUBECONFIG="${KUBECONFIG}:${_config}" kubectl config view --flatten >"${KUBECONFIG}.merged"
    mv "${KUBECONFIG}.merged" "${KUBECONFIG}"
    chmod 600 "$KUBECONFIG"
    kubectl config use-context "$_context_sks"
    sc_context_init_generic "$_context_sks" "$_ST_CONTEXT_KUBERNETES"
}
export -f sc_context_init_kube

# Adds noop cluster and user.
function sc_context_init_noop() {
    local -r _tmp_key=/tmp/key.pem
    local -r _tmp_cert=/tmp/cert.pem

    openssl req -x509 -newkey rsa:2048 -days 365 -noenc -config "${_ST_HOME_STEM}/rc/templates/openssl.cnf" \
        -keyout $_tmp_key \
        -out $_tmp_cert &>/dev/null

    kubectl config set-cluster "$_ST_CONTEXTS_NOOP" \
        --server https://localhost \
        --embed-certs \
        --certificate-authority $_tmp_cert
    kubectl config set-credentials "$_ST_CONTEXTS_NOOP" \
        --embed-certs \
        --client-key $_tmp_key \
        --client-certificate $_tmp_cert
}

# Initializes available contexts.
function sc_context_init() {
    if ! kubectl config view | grep -q "name: $_ST_CONTEXTS_NOOP"; then
        sc_context_init_noop
    fi
    for _context in "${_ST_CONTEXTS[@]}"; do
        if ! kubectl config get-contexts $_context &>/dev/null; then
            kubectl config set-context $_context \
                --cluster "$_ST_CONTEXTS_NOOP" \
                --user "$_ST_CONTEXTS_NOOP" \
                --namespace serenditree
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
# $1: Optional ID of the context to set.
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
        nl -w1 -s' '

    local _ready=1
    [[ -n "$_ST_CONTEXT" ]] && sc_cluster_status && _ready=0

    return $_ready
}
export -f sc_context
