#!/usr/bin/env bash
########################################################################################################################
# CONTEXT
# Define and use serenditree contexts.
########################################################################################################################

# Returns the kubernetes cluster domain.
function sc_context_cluster_domain() {
    if [[ -n "$_ST_CONTEXT_KUBERNETES" ]]; then
        echo "$(kubectl config get-contexts "$_ST_CONTEXT_KUBERNETES" --no-headers | awk '{print $3}').cluster.local"
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

# Fetches and sets the context of the remote kubernetes cluster.
function sc_context_init_kube() {
    echo "Fetching kubeconfig..."
    local -r _config=${KUBECONFIG}.sks
    local -r _ttl="$((60 * 60 * 24 * 90))"
    local -r _group="system:masters"
    until exo compute sks kubeconfig serenditree kube-admin --ttl $_ttl --group $_group  --zone at-vie-1 >"$_config"
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
# $1 Name for cluster and user
function sc_context_init_noop() {
    cat > /tmp/openssl.cnf <<EOL
[req]
default_bits       = 2048
default_md         = sha256
distinguished_name = req_distinguished_name
x509_extensions    = v3_ca
prompt             = no

[req_distinguished_name]
C  = AT
ST = Vienna
L  = Vienna
O  = Serenditree
OU = Serenditree
CN = serenditree.io

[v3_ca]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer:always
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOL
    openssl req -x509 -newkey rsa:2048 -days 365 -noenc -config /tmp/openssl.cnf \
        -keyout /tmp/key.pem \
        -out /tmp/cert.pem &>/dev/null

    local -r _noop=$1
    kubectl config set-cluster $_noop --server https://localhost --embed-certs --certificate-authority /tmp/cert.pem
    kubectl config set-credentials $_noop --embed-certs --client-key /tmp/key.pem --client-certificate /tmp/cert.pem
}

# Initializes available contexts.
function sc_context_init() {
    local -r _noop=noop/serenditree
    if ! kubectl config view | grep -q "$_noop"; then
        sc_context_init_noop $_noop
    fi
    for _context in "${_ST_CONTEXTS[@]}"; do
        if ! kubectl config get-contexts $_context &>/dev/null; then
            kubectl config set-context $_context --cluster $_noop --user $_noop --namespace serenditree
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

    local _authenticated=1
    sc_cluster_status && _authenticated=0

    return $_authenticated
}
export -f sc_context
