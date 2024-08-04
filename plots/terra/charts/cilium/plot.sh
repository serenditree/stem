#!/usr/bin/env bash
########################################################################################################################
# TERRA
########################################################################################################################
_SERVICE=terra-cilium
_ORDINAL=1

_IMAGE=-
_TAG=-

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# UP
########################################################################################################################
if [[ " $* " =~ " up " ]] && [[ -n "$_ST_CONTEXT_CLUSTER" ]] && [[ -n "$_ARG_SETUP" ]]; then
    sc_heading 1 "Setting up $_SERVICE"
    if [[ -z "$_ARG_DRYRUN" ]]; then
        _ipsec_key="$(dd if=/dev/urandom count=20 bs=1 2>/dev/null | hexdump -ve '1/1 "%02x"')"

        kubectl create secret generic cilium-ipsec-keys \
            --namespace kube-system \
            --from-literal=keys="3+ rfc4106(gcm(aes)) $_ipsec_key 128"

        _ST_HELM_NAME=cilium
        _ST_HELM_ARGS="--namespace kube-system --wait --wait-for-jobs"
    fi

    sc_heading 2 "Waiting for 'helm $_ST_HELM_CMD cilium' to succeed..."
    helm $_ST_HELM_CMD $_ST_HELM_NAME . $_ST_HELM_ARGS | $_ST_HELM_PIPE

    if [[ -z "$_ARG_DRYRUN" ]]; then
        sc_heading 2 "Setting up policies..."
        helm upgrade cilium . --namespace kube-system --reuse-values --set global.setupPolicies=true
        sc_heading 2 "Restarting csi..."
        kubectl --namespace kube-system rollout restart ds exoscale-csi-node
        kubectl --namespace kube-system rollout status ds exoscale-csi-node --watch
        sc_heading 2 "Waiting for all pods to become ready..."
        kubectl wait --for condition=ready --all pod --namespace kube-system --timeout 5m
    fi
fi
