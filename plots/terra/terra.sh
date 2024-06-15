#!/usr/bin/env bash
########################################################################################################################
# TERRA
# Cloud infrastructure setup.
########################################################################################################################

if [[ -n "$_ST_CONTEXT_IS_KUBERNETES" ]]; then
    _ST_TERRA_DIR="kubernetes"
else
    _ST_TERRA_DIR="openshift"
    _ST_TERRA_ASSETS_DIR="${_ST_TERRA_DIR}/modules/bootstrap/assets/${_ST_STAGE}"
fi

function sc_terra_up_init() {
    sc_heading 1 "Initializing terraform"
    # Clean and initialize terraform
    rm -rfv "${_ST_TERRA_DIR}/"{.terraform,terraform*,modules/bootstrap/assets}
    terraform -chdir="$_ST_TERRA_DIR" init -upgrade=true

    # Update versions in versions.tf
    local -r _versions_tf=$(find "${_ST_TERRA_DIR}" -name versions.tf)
    sed -En \
        -e 's/provider "registry.terraform.io\/(.+)".*/\1/p' \
        -e 's/.*version.*=.*"(.+)".*/\1/p' \
        "${_ST_TERRA_DIR}/.terraform.lock.hcl" |
        xargs -n2 echo |
        while read -r _version; do
            echo "Setting ${_version// / to }..."
            _version=${_version//\//\\\/}
            sed -Ei "/${_version% *}/,/version/s/(.*>= )[[:digit:].]+(.*)/\1${_version#* }\2/" $_versions_tf
        done
}

function sc_terra_up_validate() {
    terraform -chdir="$_ST_TERRA_DIR" validate
}

function sc_terra_up_assets() {
    sc_terra_down_assets
    sc_terra_down_bucket
    sc_heading 2 "Creating assets..."
    terraform -chdir="$_ST_TERRA_DIR" apply \
        -auto-approve \
        -target="module.bootstrap.null_resource.create_assets[0]" \
        -replace="module.bootstrap.null_resource.create_assets[0]" \
        -var="api_key=${_ST_TERRA_API_KEY}" \
        -var="api_secret=${_ST_TERRA_API_SECRET}" \
        -var="cluster_name=${_ST_STAGE}"
}

function sc_terra_up_context() {
    sc_heading 1 "Setting up context"
    if kubectl config get-contexts "$_ST_CONTEXT_KUBERNETES" &>/dev/null; then
        local -r _cluster=$(kubectl config get-contexts "$_ST_CONTEXT_KUBERNETES" --no-headers |
            tr -d '*' | awk '{print $2}')
        local -r _user=$(kubectl config get-contexts "$_ST_CONTEXT_KUBERNETES" --no-headers |
            tr -d '*' | awk '{print $3}')
        kubectl config delete-context "$_ST_CONTEXT_KUBERNETES"
        kubectl config delete-cluster "$_cluster"
        kubectl config delete-user "$_user"
    fi
    local -r _kubeconfig_sks=${KUBECONFIG}.sks
    echo -n "Creating backup of ${KUBECONFIG}: "
    cp -v "$KUBECONFIG" "${KUBECONFIG}.bak"
    local -r _context_sks="$(sed -En 's/.*current-context: (.*)/\1/p' "$_kubeconfig_sks")"
    sed -i '/current-context/d' "$_kubeconfig_sks"
    echo "Merging contexts..."
    KUBECONFIG="${KUBECONFIG}:${_kubeconfig_sks}" kubectl config view --flatten >"${KUBECONFIG}.merged"
    mv "${KUBECONFIG}.merged" "${KUBECONFIG}"
    chmod 600 "$KUBECONFIG"
    kubectl config use-context "$_context_sks"
    sc_context_init_generic "$_context_sks" "$_ST_CONTEXT_KUBERNETES"
}

function sc_terra_up() {
    if [[ -n "$_ARG_INIT" ]]; then
        sc_terra_up_init
    else
        sc_terra_up_init
        local -r _plan='serenditree.tfplan'
        local -r _plan_realpath="$(realpath $0 | xargs dirname)/${_ST_TERRA_DIR}/${_plan}"
        # shellcheck disable=SC2064
        trap "rm -f $_plan_realpath" EXIT
        terraform -chdir="$_ST_TERRA_DIR" plan \
            -var="api_key=${_ST_TERRA_API_KEY}" \
            -var="api_secret=${_ST_TERRA_API_SECRET}" \
            -var="kubeconfig=${KUBECONFIG}.sks" \
            -out "$_plan"

        local -r _path='.variables.kubernetes_version.value'
        local -r _kubernetes_version="$(terraform -chdir="$_ST_TERRA_DIR" show -json $_plan | jq -r "$_path")"

        if exo compute sks versions --output-format text | grep -Eq "^${_kubernetes_version}$"; then
            [[ -z "$_ARG_DRYRUN" ]] && terraform -chdir="$_ST_TERRA_DIR" apply "$_plan" || exit 1


            if [[ -z "$_ARG_DRYRUN" ]]; then
                sc_terra_up_context
                echo "Patching storage class..."
                kubectl patch storageclass exoscale-sbs \
                    --namespace kube-system \
                    --patch '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
            fi
        else
            echo "Kubernetes version $_kubernetes_version is not available. Aborting..."
            exit 1
        fi
    fi
}

function sc_terra_down_assets() {
    sc_heading 2 "Removing assets..."
    rm -rfv "${_ST_TERRA_ASSETS_DIR}"
}

function sc_terra_down_bucket() {
    sc_heading 2 "Removing bucket..."
    if exo storage show sos://okd 2>/dev/null; then
        exo storage rb sos://okd --recursive --force
    else
        echo "error: bucket does not exits."
    fi
}

function sc_terra_down_loadbalancer() {
    exo compute nlb list --output-template '{{.ID}}' | xargs exo compute nlb rm --force
}

function sc_terra_down_dns() {
    echo "Removing A record..."
    exo dns show serenditree.io A --output-template '{{.ID}}' |
        xargs exo dns remove serenditree.io --force
    echo "Removing CNAME record \"www\"..."
    exo dns remove serenditree.io www --force
}

function sc_terra_down_volumes() {
    exo compute block-storage list --output-template '{{.ID}}' |
        xargs -n1 exo compute block-storage delete --force
}

function sc_terra_down() {
    if [[ -z "$_ARG_DRYRUN" ]]; then
        terraform -chdir="$_ST_TERRA_DIR" destroy \
            -var="api_key=${_ST_TERRA_API_KEY}" \
            -var="api_secret=${_ST_TERRA_API_SECRET}"

        sc_prompt "Remove DNS records?" sc_terra_down_dns
        if [[ -n "${_ST_CONTEXT_KUBERNETES}" ]]; then
            sc_prompt "Delete loadbalancer?" sc_terra_down_loadbalancer
            sc_prompt "Delete volumes?" sc_terra_down_volumes
        fi
        if [[ -n "${_ST_CONTEXT_OPENSHIFT}" ]]; then
            sc_prompt "Remove bucket?" sc_terra_down_bucket
            sc_prompt "Remove assets?" sc_terra_down_assets
        fi
    fi
}
