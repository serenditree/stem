#!/usr/bin/env bash
########################################################################################################################
# Vault init
########################################################################################################################
_NAMESPACE="terra-vault"
_POD="vault-0"

function sc_vault_init() {
    echo -n "Initializing vault..."
    kubectl exec --namespace $_NAMESPACE $_POD -- bao operator init \
        -key-shares=5 \
        -key-threshold=3 \
        -format=json |
        pass insert --force --multiline serenditree/vault >/dev/null &&
        echo "done"
}
sc_vault_init

echo -n "Setting root-token..."
_ROOT_TOKEN="$(pass serenditree/vault | jq -r '.root_token')"

function sc_vault_unseal() {
    echo "Unsealing vault..."
    local -r _unseal_key_1=$(pass serenditree/vault | jq -r '.unseal_keys_b64[0]')
    local -r _unseal_key_2=$(pass serenditree/vault | jq -r '.unseal_keys_b64[1]')
    local -r _unseal_key_3=$(pass serenditree/vault | jq -r '.unseal_keys_b64[2]')
    kubectl exec --namespace $_NAMESPACE $_POD -- bao operator unseal "$_unseal_key_1"
    kubectl exec --namespace $_NAMESPACE $_POD -- bao operator unseal "$_unseal_key_2"
    kubectl exec --namespace $_NAMESPACE $_POD -- bao operator unseal "$_unseal_key_3"
}
sc_vault_unseal

function sc_vault_kv_v2() {
    echo "Enabling kv-v2..."
    kubectl exec --namespace $_NAMESPACE $_POD -- sh -c "
    BAO_TOKEN=$_ROOT_TOKEN bao secrets enable -path=serenditree kv-v2
    "
}
sc_vault_kv_v2
########################################################################################################################
# Creating policy
########################################################################################################################
function sc_vault_policy() {
   echo "Creating policy for external-secrets operator..."
   kubectl exec --namespace $_NAMESPACE $_POD -- sh -c "
cat <<EOF | BAO_TOKEN=$_ROOT_TOKEN bao policy write serenditree -
path \"serenditree/data/*\" {
 capabilities = [\"read\"]
}
path \"serenditree/metadata/*\" {
 capabilities = [\"read\"]
}
EOF
"
}
sc_vault_policy

function sc_vault_policy_token() {
    echo "Creating token for policy..."
    local -r _policy_token="$(
        kubectl exec --namespace $_NAMESPACE $_POD -- sh -c "
            BAO_TOKEN=$_ROOT_TOKEN bao token create -policy=serenditree -format=json
            " |
            jq -r '.auth.client_token'
    )"
    kubectl create secret generic terra-vault-token \
        --from-literal=token="$_policy_token" \
        --namespace $_NAMESPACE
}
sc_vault_policy_token
########################################################################################################################
# Putting secrets
########################################################################################################################
function sc_vault_put() {
    local -r _cmd="\nBAO_TOKEN=$_ROOT_TOKEN bao kv put 'serenditree"
    local -r _out=">/dev/null && echo PUT serenditree/X"
    local _cmds=
    local _path=

    for _folder in app cicd o11y oidc iam; do
        echo -n "Preparing vault-secrets for ${_folder}..." >&2
        while read -r _item; do
            if [[ "$_folder" == "oidc" ]]; then
                _country="${_item%.*}"
                if [[ "${_item#*.}" == "id" ]]; then
                    _path="${_folder}/${_country}/country"
                    _cmds+="${_cmd}/${_path}' value='${_country}' ${_out//X/$_path}"
                fi
                _path="${_folder}/${_country}/${_item#*.}"
                _cmds+="${_cmd}/${_path}' value='$(pass "serenditree/oidc/${_country}.${_item#*.}")' ${_out//X/$_path}"
            else
                _path="${_folder}/${_item//./\/}"
                _cmds+="${_cmd}/${_path}' value='$(pass "serenditree/${_folder}/${_item}")' ${_out//X/$_path}"
            fi
        done < <(pass "serenditree/${_folder}" | sed -En 's/.* ([a-zA-Z.]+)/\1/p')
        echo "done" >&2
    done
    kubectl exec --namespace $_NAMESPACE $_POD -- sh -c "$(echo -e "$_cmds")"
}
sc_vault_put

