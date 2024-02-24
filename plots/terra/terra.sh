#!/usr/bin/env bash
########################################################################################################################
# TERRA
# Cloud infrastructure setup.
########################################################################################################################

_ST_TERRA_PREFIX="serenditree-${_ST_STAGE}"
if [[ -n "$_ST_CONTEXT_IS_KUBERNETES" ]]; then
    _ST_TERRA_DIR="kubernetes"
else
    _ST_TERRA_DIR="openshift"
    _ST_TERRA_ASSETS_DIR="${_ST_TERRA_DIR}/modules/bootstrap/assets/${_ST_STAGE}"
    _ST_BOOTSTRAP="${_ST_TERRA_PREFIX}-bootstrap"
    _ST_MASTER="${_ST_TERRA_PREFIX}-master"
fi

########################################################################################################################
# DESCRIPTIVE
########################################################################################################################

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

function sc_terra_up_ingress() {
    echo "Checking preconditions for ingress setup..." &&
        [[ $(exo compute nlb list | wc -l) -gt 0 ]] &&
        echo "Found existing load-balancer. Aborting..." &&
        exit 1
    echo "Deploying nginx ingress..."
    local _ingress_rc
    _ingress_rc='https://raw.githubusercontent.com/kubernetes/ingress-nginx'
    _ingress_rc+='/master/deploy/static/provider/exoscale/deploy.yaml'
    kubectl apply --filename $_ingress_rc
    echo "Patching nginx ingress..."
    sc_cluster_patch nginx-ingress

    echo "Waiting for load-balancer..."
    until [[ $(exo compute nlb list | wc -l) -gt 0 ]]; do
        sleep 1s
    done
    local _nlb_id
    _nlb_id="$(exo compute nlb list --output-template '{{.ID}}')"
    echo "Load-balancer ID: ${_nlb_id}"
    local _nlb_ip
    until [[ -n "$_nlb_ip" ]]; do
        _nlb_ip=$(exo compute nlb show "$_nlb_id" --output-format json | jq -r '.ip_address')
        sleep 1s
    done
    echo "Load-balancer IP: ${_nlb_ip}"
    echo "Updating load-balancer name..."
    exo compute nlb update "${_nlb_id}" --name serenditree

    sc_heading 1 "Setting up dns records..."
    exo dns add A "serenditree.io" --name "" --address "$_nlb_ip"
    exo dns add CNAME "serenditree.io" --name "www" --alias "serenditree.io"
    exo dns show "serenditree.io" --output-template "{{.ID}};{{.Name}};{{.RecordType}};{{.Content}};{{.TTL}}" |
        sort -t ';' -k 3 |
        column -ts ';'
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

function sc_terra_up() {
    if [[ -n "$_ARG_INIT" ]]; then
        sc_terra_up_init
    else
        [[ -z "$_ARG_DRYRUN" ]] && terraform -chdir="$_ST_TERRA_DIR" apply \
            -var="api_key=${_ST_TERRA_API_KEY}" \
            -var="api_secret=${_ST_TERRA_API_SECRET}"

        sc_heading 1 "Setting up kubernetes context"
        [[ -z "$_ARG_DRYRUN" ]] && sc_context_init_kube

        sc_heading 1 "Setting up ingress controller"
        sc_terra_up_ingress
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
    exo dns show serenditree.io A --output-template '{{.ID}}' | xargs exo dns remove serenditree.io --force
    echo "Removing CNAME record \"www\"..."
    exo dns remove serenditree.io www --force
}

function sc_terra_down() {
    if [[ -z "$_ARG_DRYRUN" ]]; then
        terraform -chdir="$_ST_TERRA_DIR" destroy \
            -var="api_key=${_ST_TERRA_API_KEY}" \
            -var="api_secret=${_ST_TERRA_API_SECRET}"

        if [[ -n "${_ST_CONTEXT_KUBERNETES}" ]]; then
            sc_prompt "Delete loadbalancer?" sc_terra_down_loadbalancer
        fi
        sc_prompt "Remove DNS records?" sc_terra_down_dns
        if [[ -n "${_ST_CONTEXT_OPENSHIFT}" ]]; then
            sc_prompt "Remove bucket?" sc_terra_down_bucket
            sc_prompt "Remove assets?" sc_terra_down_assets
        fi
    fi
}

########################################################################################################################
# IMPERATIVE
########################################################################################################################

function sc_up_imperative_apply_security_group() {
    exo firewall create "$_ST_TERRA_PREFIX"
    exo firewall add "$_ST_TERRA_PREFIX" ping
    exo firewall add "$_ST_TERRA_PREFIX" ssh
    for _port in "1936" "2379-2380" "6443" "9000-9999" "10250-10259" "22623" "30000-32767"; do
        exo firewall add "$_ST_TERRA_PREFIX" \
            --protocol "tcp" \
            --cidr "0.0.0.0/0" \
            --port "$_port"
    done
    for _port in "4789" "6081" "9000-9999" "30000-32767"; do
        exo firewall add "$_ST_TERRA_PREFIX" \
            --protocol "udp" \
            --cidr "0.0.0.0/0" \
            --port "$_port"
    done
}

function sc_up_imperative_apply_bootstrap_instance() {
    exo compute instance create "$_ST_BOOTSTRAP" \
        --zone at-vie-2 \
        --ssh-key tanwald1 \
        --security-group "$_ST_TERRA_PREFIX" \
        --template dde12e2f-0fc0-4d89-b4e8-07d97ce5a966 \
        --instance-type "standard.extra-large" \
        --disk-size 120 \
        --cloud-init "${_ST_TERRA_ASSETS_DIR}/bootstrap.remote.ign"
}

function sc_up_imperative_apply_bootstrap_dns() {
    local -r _bootstrap_ip=$(exo compute instance show "$_ST_BOOTSTRAP" --output-format json | jq -r '.ip_address')
    for _domain_name in "bootstrap" "api" "api-int"; do
        exo dns add A "serenditree.io" \
            --name "${_domain_name}.${_ST_STAGE}" \
            --address "$_bootstrap_ip" \
            --ttl 60
    done
    echo -n "Waiting for bootstrap cluster..."
    until curl -ksm 5 "https://${_bootstrap_ip}:6443/readyz"; do echo -n "." && sleep 5s; done
}

function sc_up_imperative_apply_master_instance_pool() {
    exo instancepool create "$_ST_MASTER" \
        --zone at-vie-2 \
        --keypair tanwald1 \
        --security-group "$_ST_TERRA_PREFIX" \
        --template dde12e2f-0fc0-4d89-b4e8-07d97ce5a966 \
        --service-offering extra-large \
        --disk 120 \
        --cloud-init "${_ST_TERRA_ASSETS_DIR}/master.ign" \
        --instance-prefix pool \
        --size 3
}

function sc_up_imperative_apply_master_dns() {
    local _index=1
    exo compute instance list --output-format json | jq -r '.[] | select(.name | startswith("pool")) | .ip_address' |
        while read -r _ip_address; do
            _domain_name="master${_index}.${_ST_STAGE}"
            echo "Creating A record ${_domain_name} for ${_ip_address}"
            exo dns add A "serenditree.io" --name "$_domain_name" --address "$_ip_address"
            ((++_index))
        done
}

function sc_up_imperative_apply_master_nlb() {
    exo nlb create "$_ST_MASTER" --zone at-vie-2
    for _service in "http:80" "https:443" "api:6443" "machine-config-server:22623"; do
        exo nlb service add "$_ST_MASTER" "${_ST_MASTER}-${_service%:*}" \
            --instance-pool "$_ST_MASTER" \
            --zone at-vie-2 \
            --port ${_service#*:} \
            --target-port ${_service#*:} \
            --protocol tcp \
            --strategy round-robin
    done
}

function sc_up_imperative_apply_master_handover() {
    sc_heading 2 "Removing bootstrap resources..."
    for _domain_name in "bootstrap" "api" "api-int"; do
        exo dns remove "serenditree.io" "${_domain_name}.${_ST_STAGE}" --force
    done
    exo compute instance delete "$_ST_BOOTSTRAP"

    sc_heading 2 "Adding loadbalancer DNS entries..."
    local -r _master_nlb_ip=$(exo nlb show "$_ST_MASTER" --output-format json | jq -r '.ip_address')
    for _domain_name in "api" "api-int" "*.apps"; do
        exo dns add A "serenditree.io" --name "${_domain_name}.${_ST_STAGE}" --address "$_master_nlb_ip"
    done
}

function sc_up_imperative_apply() {
    pushd "${_ST_TERRA_DIR}" >/dev/null

    sc_prompt "Create assets?" sc_terra_up_assets
    sc_prompt "Create security group?" sc_up_imperative_apply_security_group

    sc_prompt "Create bootstrap instance?" sc_up_imperative_apply_bootstrap_instance ||
        { cat "${_ST_TERRA_ASSETS_DIR}/bootstrap.remote.ign" &&
            echo -e "\nName: ${_ST_BOOTSTRAP}\nReverse DNS: bootstrap.${_ST_STAGE}.serenditree.io."; }
    sc_prompt "Add bootstrap DNS entries?" sc_up_imperative_apply_bootstrap_dns

    sc_prompt "Create master instance-pool?" sc_up_imperative_apply_master_instance_pool ||
        { cat "${_ST_TERRA_ASSETS_DIR}/master.ign" &&
            echo -e "\nName: ${_ST_MASTER}\nReverse DNS: master<n>.${_ST_STAGE}.serenditree.io."; }
    sc_prompt "Add master DNS entries?" sc_up_imperative_apply_master_dns
    sc_prompt "Create master load balancer?" sc_up_imperative_apply_master_nlb

    openshift-install --dir="${_ST_TERRA_ASSETS_DIR}" --log-level=debug wait-for bootstrap-complete

    sc_prompt "Handover to master?" sc_up_imperative_apply_master_handover

    openshift-install --dir="${_ST_TERRA_ASSETS_DIR}" --log-level=debug wait-for install-complete

    popd >/dev/null
}

function sc_up_imperative_destroy() {
    sc_heading 2 "Deleting bootstrap instance..."
    exo compute instance delete "$_ST_BOOTSTRAP" --force
    sc_heading 2 "Deleting master loadbalancer..."
    exo nlb delete "$_ST_MASTER" --force
    sc_heading 2 "Deleting master instance-pool..."
    exo instancepool delete "$_ST_MASTER" --force

    sc_heading 2 "Removing domain records..."
    for _domain_name in "bootstrap" "api" "api-int" "*.apps"; do
        echo -n "${_domain_name}.${_ST_STAGE}: "
        exo dns remove "serenditree.io" "${_domain_name}.${_ST_STAGE}" --force
    done
    for _index in $(seq 3); do
        echo -n "master${_index}.${_ST_STAGE}: "
        exo dns remove "serenditree.io" "master${_index}.${_ST_STAGE}" --force
    done

    echo -n "Waiting until all instances are deleted..."
    until [ "$(exo compute instance list --output-format json | jq 'length')" -eq 0 ]; do
        echo -n "." && sleep 5s
    done && echo "ok"
    sc_heading 2 "Deleting security group..."
    exo firewall delete "$_ST_TERRA_PREFIX" --force

    sc_terra_down_bucket
    sc_terra_down_assets
}
