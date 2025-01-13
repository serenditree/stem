#!/usr/bin/env bash
########################################################################################################################
# TERRA
# Cloud infrastructure setup.
########################################################################################################################
# Utils
########################################################################################################################
function sc_terra_secrets() {
    local -r _target=$1
    local _index=0

    echo -n "Setting sensitive ${_target}-parameters..." >&2
    _JSON="{"
    while read -r _item; do
        if [[ "$_target" == "app" ]] || [[ "$_target" == "cicd" ]]; then
            _JSON+="\"${_item}\": \"$(pass serenditree/${_target}/${_item})\", "
        elif [[ "$_target" == "oidc" ]]; then
            _COUNTRY="${_item%.*}"
            if [[ "${_item#*.}" == "id" ]]; then
                _JSON+="\"branch.parameters.oidc[${_index}].country\": \"${_COUNTRY}\", "
                _JSON+="\"branch.parameters.oidc[${_index}].id\": \"$(pass serenditree/oidc/${_item})\", "
                _JSON+="\"branch.parameters.oidc[${_index}].idRef\": \"oidc-id-${_COUNTRY}\", "
            elif [[ "${_item#*.}" == "secret" ]]; then
                _JSON+="\"branch.parameters.oidc[${_index}].secret\": \"$(pass serenditree/oidc/${_item})\", "
                _JSON+="\"branch.parameters.oidc[${_index}].secretRef\": \"oidc-secret-${_COUNTRY}\", "
            else
                _JSON+="\"branch.parameters.oidc[${_index}].url\": \"$(pass serenditree/oidc/${_item})\", "
                _JSON+="\"branch.parameters.oidc[${_index}].urlRef\": \"oidc-url-${_COUNTRY}\", "
                ((_index++))
            fi
        else
            echo "Invalid target '${_target}'"
            exit 1
        fi
    done < <(pass "serenditree/${_target}" | sed -En 's/.* ([a-zA-Z.]+)/\1/p')
    _JSON="${_JSON%,*}}"
    echo "$_JSON" | jq -c
    echo "done" >&2
}

function sc_terra_render() {
    local -r _plan="$1"
    sc_heading 1 "Rendering apps"
    terraform -chdir="$_ST_CONTEXT_HOME" show -json "$_plan" |
        jq ".resource_changes[] | select(.type == \"helm_release\" and .name == \"serenditree\") | \
            .change.after.set[] | \"--set=\(.name)=\(.value)\"" |
        xargs helm template "${_ST_HOME_STEM}/charts/tree" |
        sed -E 's/sync-wave: "([-0-9]+)"/sync-wave: \1/' |
        yq eval-all '[.] | sort_by(.metadata.annotations."argocd.argoproj.io/sync-wave") | .[] | splitDoc' |
        sed -E 's/sync-wave: ([-0-9]+)/sync-wave: "\1"/' |
        yq
}
function sc_terra_versions() {
    local -r _versions_tf=$(find "${_ST_CONTEXT_HOME}" -name versions.tf)
    sed -En \
        -e 's/provider "registry.terraform.io\/(.+)".*/\1/p' \
        -e 's/.*version.*=.*"(.+)".*/\1/p' \
        "${_ST_CONTEXT_HOME}/.terraform.lock.hcl" |
        xargs -n2 echo |
        while read -r _version; do
            echo "Setting ${_version// / to }..."
            _version=${_version//\//\\\/}
            sed -Ei "/${_version% *}/,/version/s/(.*>= )[[:digit:].]+(.*)/\1${_version#* }\2/" $_versions_tf
        done
}
########################################################################################################################
# Up
########################################################################################################################
function sc_terra_up_init() {
    sc_heading 1 "Initializing terraform"
    if [[ -n "$_ARG_INIT" ]]; then
        rm -rf "${_ST_CONTEXT_HOME}/"{terraform*,.terraform,modules/bootstrap/assets}
    fi
    terraform -chdir="$_ST_CONTEXT_HOME" init -upgrade=true
    sc_terra_versions
}

function sc_terra_up_assets() {
    sc_terra_down_assets
    sc_terra_down_bucket
    sc_heading 2 "Creating assets..."
    terraform -chdir="$_ST_CONTEXT_HOME" apply \
        -auto-approve \
        -target="module.bootstrap.null_resource.create_assets[0]" \
        -replace="module.bootstrap.null_resource.create_assets[0]" \
        -var="api_key=$(pass serenditree/iam/serenditree@exoscale.com.access)" \
        -var="api_secret=$(pass serenditree/iam/serenditree@exoscale.com.secret)" \
        -var="cluster_name=${_ST_STAGE}"
}

function sc_terra_up_iam() {
    for _role in backup data scaler traces; do
        echo -n "Saving credentials for ${_role}..."
        local _file="${_ST_CONTEXT_HOME}/${_role}.iam"
        local _prefix="serenditree/iam/${_role}@exoscale.com"
        if cut -d':' -f1 "${_file}" | pass insert --force --multiline "${_prefix}.access" &>/dev/null; then
            if cut -d':' -f2 "${_file}" | pass insert --force --multiline "${_prefix}.secret" &>/dev/null; then
                echo "done"
                rm "${_file}"
            else
                echo "error"
            fi
        else
            echo "error"
        fi
    done
}

function sc_terra_up() {
    if exo compute sks versions --output-format text | grep -Eq "^${_ST_VERSION_KUBERNETES}$"; then
        sc_terra_up_init

        if [[ -n "$_ARG_DRYRUN" ]]; then
            local -r _serenditree_tf="${_ST_CONTEXT_HOME}/serenditree.tf"
            # shellcheck disable=SC2064
            trap "mv ${_serenditree_tf}.bak ${_serenditree_tf}" EXIT
            sed -Ei.bak 's/set_sensitive/set/' "${_serenditree_tf}"
        fi

        sc_heading 1 "Planing terraform"
        local -r _plan='serenditree.tfplan'
        terraform -chdir="$_ST_CONTEXT_HOME" plan \
            -var=api_key="$(pass serenditree/iam/serenditree@exoscale.com.access)" \
            -var=api_secret="$(pass serenditree/iam/serenditree@exoscale.com.secret)" \
            -var=kubernetes_version="${_ST_VERSION_KUBERNETES}" \
            -var=account="${_ST_ACCOUNT}" \
            -var=context="${_ST_CONTEXT}" \
            -var=cluster_domain="cluster.local" \
            -var=stage="${_ST_STAGE}" \
            -var=host="${_ST_DOMAIN}" \
            -var=issuer="${_ARG_ISSUER}" \
            -var=zone="${_ST_ZONE}" \
            -var=git_repo="${_ST_GIT}" \
            -var=git_ssh="${_ST_GIT_SSH}" \
            -var=app_parameters="$(sc_terra_secrets app)" \
            -var=cicd_parameters="$(sc_terra_secrets cicd)" \
            -var=oidc_parameters="$(sc_terra_secrets oidc)" \
            -out "$_plan"

        if [[ -n "$_ARG_DRYRUN" ]]; then
            sc_terra_render "$_plan"
        else
            sc_heading 1 "Applying terraform"
            terraform -chdir="$_ST_CONTEXT_HOME" apply "$_plan"
            sc_heading 1 "Backing up IAM credentials"
            sc_terra_up_iam
            sc_heading 1 "Setting up context"
            sc_context_clean
            sc_context_init_kube "${_ST_CONTEXT_HOME}/kubeconfig"
        fi
    else
        echo "Kubernetes version $_ST_VERSION_KUBERNETES is not available. Aborting..."
        exit 1
    fi
}
########################################################################################################################
# Down
########################################################################################################################
function sc_terra_down_dns() {
    echo "Removing A record..."
    exo dns show "$_ST_DOMAIN" A --output-template '{{.ID}}' |
        xargs exo dns remove "$_ST_DOMAIN" --force
    echo "Removing CNAME record \"www\"..."
    exo dns remove "$_ST_DOMAIN" www --force
}

function sc_terra_down_loadbalancer() {
    echo "Deleting loadbalancer..."
    exo compute nlb rm --force "serenditree"
}

function sc_terra_down_volumes() {
    echo "Deleting volumes..."
    xargs -n1 exo compute block-storage delete --force </tmp/serenditree-pv
}

function sc_terra_down_bucket() {
    echo "Removing bucket..."
    if exo storage show sos://okd 2>/dev/null; then
        exo storage rb sos://okd --recursive --force
    else
        echo "error: bucket does not exits."
    fi
}

function sc_terra_down_assets() {
    echo "Removing assets..."
    rm -rfv "${_ST_CONTEXT_HOME}/modules/bootstrap/assets/${_ST_STAGE}"
}

function sc_terra_down() {
    if [[ -z "$_ARG_DRYRUN" ]]; then
        sc_heading 2 "Cluster volumes:"
        kubectl get pv --output=custom-columns='name:.metadata.name' --no-headers | tee /tmp/serenditree-pv

        sc_heading 2 "Removing helm releases from state..."
        terraform -chdir="$_ST_CONTEXT_HOME" show -json serenditree.tfplan |
            jq -r ".configuration.root_module.resources[] | select(.type == \"helm_release\") | .address" |
            xargs terraform -chdir="$_ST_CONTEXT_HOME" state rm

        sc_heading 2 "Starting deletion..."
        terraform -chdir="$_ST_CONTEXT_HOME" destroy -auto-approve \
            -var=api_key="$(pass serenditree/iam/serenditree@exoscale.com.access)" \
            -var=api_secret="$(pass serenditree/iam/serenditree@exoscale.com.secret)" \
            -var=kubernetes_version="${_ST_VERSION_KUBERNETES}" \
            -var=account="${_ST_ACCOUNT}" \
            -var=context="${_ST_CONTEXT}" \
            -var=cluster_domain="cluster.local" \
            -var=stage="${_ST_STAGE}" \
            -var=host="${_ST_DOMAIN}" \
            -var=issuer="${_ARG_ISSUER}" \
            -var=zone="${_ST_ZONE}" \
            -var=git_repo="${_ST_GIT}" \
            -var=git_ssh="${_ST_GIT_SSH}" \
            -var=app_parameters="$(sc_terra_secrets app)" \
            -var=cicd_parameters="$(sc_terra_secrets cicd)" \
            -var=oidc_parameters="$(sc_terra_secrets oidc)"

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
