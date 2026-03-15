#!/usr/bin/env bash
########################################################################################################################
# TERRA
# Cloud infrastructure setup.
########################################################################################################################
# Turns key-value pairs in pass-folders (standard unix password manager) into JSON objects.
# $1: Pass folder.
function sc_terra_secrets() {
    local -r _target=$1
    local _index=0

    echo -n "Setting sensitive ${_target}-parameters..." >&2
    _JSON="{"
    while read -r _item; do
        if [[ "$_target" =~ ^(app|cicd|o11y)$ ]]; then
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

# Renders ArgoCD applications using values from the IaC plan (OpenTofu).
function sc_terra_render() {
    sc_heading 1 "Rendering apps"
    tofu -chdir="$_ST_CONTEXT_HOME" show -json "$_ST_CONTEXT_PLAN" |
        jq ".resource_changes[] | select(.type == \"helm_release\" and .name == \"serenditree\") | \
            .change.after.set[] | \"--set=\(.name)=\(.value)\"" |
        xargs helm template "${_ST_HOME_STEM}/charts/tree" |
        sed -E 's/sync-wave: "([-0-9]+)"/sync-wave: \1/' |
        yq eval-all '[.] | sort_by(.metadata.annotations."argocd.argoproj.io/sync-wave") | .[] | splitDoc' |
        sed -E 's/sync-wave: ([-0-9]+)/sync-wave: "\1"/' |
        yq
}

# Syncs versions.tf with versions from a lockfile.
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
# Checks if the defined kubernetes version is still supported and initializes OpenTofu.
# If the argument '--init' is given, previous initialization-artifacts are removed.
function sc_terra_up_init() {
    if exo compute sks versions --output-format text | grep -Eq "^${_ST_VERSION_KUBERNETES}$"; then
        sc_heading 1 "Initializing"
        if [[ -n "$_ARG_INIT" ]]; then
            rm -rf "${_ST_CONTEXT_HOME}/"{terraform*,.terraform,modules/bootstrap/assets}
        fi
        tofu -chdir="$_ST_CONTEXT_HOME" init -upgrade=true
    else
        echo "Kubernetes version $_ST_VERSION_KUBERNETES is not available. Aborting..."
        exit 1
    fi
}

# Generates assets needed for OpenShift setup.
function sc_terra_up_assets() {
    sc_heading 2 "Creating assets..."
    tofu -chdir="$_ST_CONTEXT_HOME" apply \
        -auto-approve \
        -target="module.bootstrap.null_resource.create_assets[0]" \
        -replace="module.bootstrap.null_resource.create_assets[0]" \
        -var="api_key=$(pass serenditree/iam/serenditree@exoscale.com.access)" \
        -var="api_secret=$(pass serenditree/iam/serenditree@exoscale.com.secret)" \
        -var="cluster_name=${_ST_STAGE}"
}

# Stores IAM keys created during setup.
function sc_terra_up_iam_backup() {
    pushd "${_ST_CONTEXT_HOME}" &>/dev/null || exit 1
    while read -r _file; do
        local _role=${_file%\.*}
        _role=${_file##*/}
        echo -n "Saving credentials for ${_role}..."
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
    done < <(ls ./*.iam)
    popd &>/dev/null || exit 1
}

# Waits for the CCM-created load-balancer to create DNS records.
function sc_terra_up_dns() {
    echo "Waiting for load-balancer..."
    until exo compute nlb list --output-template '{{.Name}}' | grep -Eq '^serenditree$'; do sleep 1s; done

    local _nlb_ip
    until [[ -n "$_nlb_ip" ]] && [[ "$_nlb_ip" != "<nil>" ]]; do
        _nlb_ip=$(exo compute nlb show 'serenditree' --output-format json | jq -r '.ip_address')
        sleep 1s
    done

    local _ttl=3600
    [[ "$_ARG_ISSUER" == "staging" ]] && _ttl=60

    exo dns add A "$_ST_DOMAIN" --name "" --address "$_nlb_ip" --ttl=$_ttl
    exo dns add CNAME "$_ST_DOMAIN" --name "www" --alias "$_ST_DOMAIN" --ttl=$_ttl
    exo dns show "$_ST_DOMAIN" --output-template "{{.ID}};{{.Name}};{{.RecordType}};{{.Content}};{{.TTL}}" |
        sort -t ';' -k 3 |
        column -ts ';'
}

function sc_terra_up_plan() {
    tofu -chdir="$_ST_CONTEXT_HOME" plan \
        -var=api_key="$(pass serenditree/iam/serenditree@exoscale.com.access)" \
        -var=api_secret="$(pass serenditree/iam/serenditree@exoscale.com.secret)" \
        -var=kubernetes_version="${_ST_VERSION_KUBERNETES}" \
        -var=context="${_ST_CONTEXT}" \
        -var=stage="${_ST_STAGE}" \
        -var=host="${_ST_DOMAIN}" \
        -var=issuer="${_ARG_ISSUER}" \
        -var=zone="${_ST_ZONE}" \
        -var=app_parameters="$(sc_terra_secrets app)" \
        -var=cicd_parameters="$(sc_terra_secrets cicd)" \
        -var=o11y_parameters="$(sc_terra_secrets o11y)" \
        -var=oidc_parameters="$(sc_terra_secrets oidc)" \
        -out "$_ST_CONTEXT_PLAN"
}

# Provisions infrastructure, configures context, bootstraps Serenditree and hands-over control to ArgoCD.
function sc_terra_up() {
    AWS_ACCESS_KEY_ID="$(pass serenditree/iam/serenditree@exoscale.com.access)"
    AWS_SECRET_ACCESS_KEY="$(pass serenditree/iam/serenditree@exoscale.com.secret)"
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

    sc_terra_up_init

    if [[ -n "${_ARG_SETUP}" ]]; then
        sc_heading 1 "Planing infrastructure"
        sc_terra_up_plan
    fi

    if [[ -n "$_ARG_DRYRUN" ]]; then
        sc_terra_render
    elif [[ -n "${_ARG_SETUP}" ]]; then
        sc_heading 1 "Applying plan"
        tofu -chdir="$_ST_CONTEXT_HOME" apply "$_ST_CONTEXT_PLAN"
        sc_heading 1 "Backing up IAM credentials"
        sc_terra_up_iam_backup
        sc_heading 1 "Setting up context"
        sc_context_clean
        sc_context_init_kube "${_ST_CONTEXT_HOME}/kubeconfig"
        sc_heading 1 "Setting up DNS"
        sc_terra_up_dns
        sc_heading 1 "Waiting for pods to become ready"
        sc_cluster_wait 10m
    fi
}
########################################################################################################################
# Down
########################################################################################################################
function sc_terra_down_dns() {
    local -r _a_record="$(exo dns show "$_ST_DOMAIN" A --output-template '{{.ID}}')"
    if [[ -n "$_a_record" ]]; then
        echo "Removing A record..."
        exo dns remove "$_ST_DOMAIN" "$_a_record" --force
        echo "Removing CNAME record \"www\"..."
        exo dns remove "$_ST_DOMAIN" www --force
    else
        echo "DNS records do not exist."
    fi
}

function sc_terra_down_loadbalancer() {
    local -r _nlb=serenditree
    if exo compute nlb show $_nlb &>/dev/null; then
        echo "Deleting loadbalancer..."
        compute nlb rm --force $_nlb
    else
        echo "Loadbalancer does not exits."
    fi
}

function sc_terra_down_volumes() {
    echo "Deleting volumes..."
    xargs -I{} -P0 -r bash -c \
        'echo "Deleting {}..." && exo compute block-storage delete --force --quiet {} && echo "Deleted {}"' \
        </tmp/serenditree-pv
}

function sc_terra_down() {
    AWS_ACCESS_KEY_ID="$(pass serenditree/iam/serenditree@exoscale.com.access)"
    AWS_SECRET_ACCESS_KEY="$(pass serenditree/iam/serenditree@exoscale.com.secret)"
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

    echo "Saving persistent volumes..."
    kubectl get pv --output=custom-columns='name:.metadata.name' --no-headers | tee /tmp/serenditree-pv

    sc_prompt "Delete loadbalancer?" && sc_terra_down_loadbalancer

    sc_prompt "Remove helm releases from terraform state?" &&
        tofu -chdir="$_ST_CONTEXT_HOME" show -json serenditree.tfplan |
            jq -r ".configuration.root_module.resources[] | select(.type == \"helm_release\") | .address" |
            xargs tofu -chdir="$_ST_CONTEXT_HOME" state rm

    sc_prompt "Destroy terraform resources?" &&
        tofu -chdir="$_ST_CONTEXT_HOME" destroy -auto-approve \
            -var=api_key="$(pass serenditree/iam/serenditree@exoscale.com.access)" \
            -var=api_secret="$(pass serenditree/iam/serenditree@exoscale.com.secret)" \
            -var=kubernetes_version="${_ST_VERSION_KUBERNETES}" \
            -var=context="${_ST_CONTEXT}" \
            -var=stage="${_ST_STAGE}" \
            -var=host="${_ST_DOMAIN}" \
            -var=issuer="${_ARG_ISSUER}" \
            -var=zone="${_ST_ZONE}" \
            -var=app_parameters="$(sc_terra_secrets app)" \
            -var=cicd_parameters="$(sc_terra_secrets cicd)" \
            -var=o11y_parameters="$(sc_terra_secrets o11y)" \
            -var=oidc_parameters="$(sc_terra_secrets oidc)"

    sc_prompt "Remove DNS records?" && sc_terra_down_dns
    sc_prompt "Delete volumes?" && sc_terra_down_volumes
}
