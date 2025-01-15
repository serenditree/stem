#!/usr/bin/env bash
########################################################################################################################
# STATUS
# Inspects the host system for problems and prints information about active contexts, containers, available plots,...
########################################################################################################################

# Checks required applications.
function sc_status_required_applications() {
    echo -n "Required applications..."
    local _required="argbash|argocd|buildah|crc|envsubst|exo|git|helm|highlight|jq|kubectl|oc|openshift-install|pass|"
    local _required+="podman|skopeo|terraform|tkn|yarnpkg"
    local -r _missing=$(
        cat <(compgen -c | grep -E "^($_required)$") <(echo -e "${_required//|/\\n}") |
            sort |
            uniq -u
    )
    if [[ -n "$_missing" ]]; then
        echo "${_BOLD}warning:${_NORMAL} $_missing not found" | xargs
    else
        echo "${_BOLD}ok${_NORMAL}"
    fi
}

# Checks required files and folders.
function sc_status_required_files() {
    echo -n "Required files..."
    if [[ -f "$_ST_GIT_SSH" ]]; then
        echo "${_BOLD}ok${_NORMAL}"
    else
        echo "${_BOLD}warning:${_NORMAL} ssh private key for argocd github access does not exits."
    fi
    echo -n "Required folders..."
    if [[ -d ~/.m2 ]]; then
        echo "${_BOLD}ok${_NORMAL}"
    else
        echo "${_BOLD}warning:${_NORMAL} local maven repository at ~/.m2 does not exits."
    fi
}

# Checks if base images are available and pulls them.
# TODO deprecated
function sc_status_build_base_images() {
    if [[ "$_ST_FROM" == "rhel" ]]; then
        echo "Checking base images..."
        sc_login redhat
        local -r _pulled=$(
            env | grep "_ST_FROM_" | cut -d'=' -f2 |
                xargs -I{} bash -c "podman image exists {} || podman pull {}" |
                wc -l
        )
        [[ $_pulled -eq 0 ]] && echo "All set!"
    fi
}

# Checks if the repository for custom node versions exists.
function sc_status_build_node() {
    echo -n "Checking nodejs repository..."
    local -r _node_repo=/etc/yum.repos.d/nodesource-nodejs.repo
    if [[ -f $_node_repo ]]; then
        echo "${_BOLD}ok${_NORMAL}"
    else
        echo " nodejs repository does not exists."
        sc_trap "sudo rm -f ${_node_repo}" EXIT
        sc_prompt "Temporarily install custom nodjs repository" &&
            curl -fsSL "https://rpm.nodesource.com/setup_${_ST_VERSION_NODE}" |
            sudo bash -
    fi
}

# Checks if repositories are ready for the installation with dnf of the host.
function sc_status_build_repos() {
    echo -n "Checking if 'countme' is disabled..."
    if grep -Eq '^countme=1' /etc/yum.repos.d/*; then
        echo " countme is enabled."
        sc_trap "sudo sed -Ei 's/^countme=0/countme=1/' /etc/yum.repos.d/*" EXIT
        sc_prompt "Temporarily disable countme" &&
            sudo sed -Ei 's/^countme=1/countme=0/' /etc/yum.repos.d/*
    else
        echo "${_BOLD}ok${_NORMAL}"
    fi
}

# Checks operating system.
function sc_status_os() {
    echo -n "Required distribution..."
    if [[ -e /etc/fedora-release ]]; then
        echo "${_BOLD}ok${_NORMAL}"
    else
        echo "${_BOLD}error:${_NORMAL} image building only tested on fedora"
    fi
    echo -n "Checking uid..."
    if [[ $(id -u) -eq 1000 ]]; then
        echo "${_BOLD}ok${_NORMAL}"
    else
        echo "${_BOLD}warning:${_NORMAL} your uid ($(id -u), not 1000) might lead to troubles."
    fi
}

# Prints registry authentications.
function sc_status_registries() {
    if [[ -n "$REGISTRY_AUTH_FILE" ]]; then
        local -r _auth_json=$REGISTRY_AUTH_FILE
    else
        local -r _auth_json=${XDG_RUNTIME_DIR}/containers/auth.json
        echo "${_BOLD}Warning:${_NORMAL} Using default auth.json (${_auth_json})"
    fi
    if [[ -e $_auth_json ]]; then
        local -r _registries="$(jq -r ".auths | keys[]" $_auth_json)"
    fi
    echo "${_registries:-none}"
}

# Prints global environment variables based on context.
function sc_status_env() {
    env | grep '^_ST_' | sed -E -e 's/=/#/' -e 's/\s+/ /g' | sort | column -ts'#' | cut -c 1-200
}

# Prints an overview of the development environment.
function sc_status() {
    sc_heading 1 "Cluster Context"
    sc_context && local -r _ready=on
    [[ -n "$_ST_CONTEXT" ]] && echo &&
        { kubectl version 2>/dev/null | sed -e '/Kustomize/d' &&
        echo "Defined Version: v${_ST_VERSION_KUBERNETES}" &&
        echo "Cluster Domain: $(sc_context_cluster_domain)"; } | column -ts':'

    if [[ -n "$_ready" ]];then
        sc_heading n 1 "Cluster"
        sc_heading 2 Pods
        kubectl get pods --all-namespaces --output wide
        echo && sc_heading 2 Apps
        echo -n "ArgoCD login..."
        if argocd version --request-timeout 1s &>/dev/null || sc_login argocd; then
            sc_heading 2 "ok"
            argocd app list
        else
            sc_heading 2 "error"
        fi
    fi

    sc_heading 1 n "System"
    sc_status_os
    sc_status_required_applications
    sc_status_required_files

    sc_heading 1 n "Registry Authentications"
    sc_status_registries

    sc_heading 1 n "Environment"
    sc_status_env

    sc_heading 1 n "Plots"
    sc_plots_inspect

    sc_heading 1 n "Local Cluster"
    if [[ -n "${_ST_CONTEXT_KUBERNETES}${_ST_CONTEXT_KUBERNETES_LOCAL}" ]]; then
        minikube config view
    else
        crc config view
    fi

    sc_heading 1 n "Local Pod"
    if podman pod exists $_ST_POD; then
        sc_pod_list
    else
        echo "down"
    fi
}
export -f sc_status
