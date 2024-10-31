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
if [[ " $* " =~ " up " ]] && [[ -n "$_ST_CONTEXT_CLUSTER" ]] && [[ -n "${_ARG_SETUP}${_ARG_UPGRADE}" ]]; then
    sc_heading 1 "Setting up $_SERVICE"
    if [[ -z "${_ARG_DRYRUN}" ]]; then
        _ST_HELM_NAME=cilium
        _ST_HELM_ARGS="--namespace kube-system --wait --wait-for-jobs"
        if [[ -z "${_ARG_UPGRADE}" ]]; then
            sc_heading 2 "Creating secret for IPsec..."
            kubectl create secret generic cilium-ipsec-key \
                --from-literal key="3+ rfc4106(gcm(aes)) $(openssl rand -hex 20) 128" \
                --namespace kube-system
        else
            _ST_HELM_ARGS+=" --reuse-values"
        fi
    fi

    sc_heading 2 "Waiting for 'helm $_ST_HELM_CMD cilium' to succeed..."
    helm $_ST_HELM_CMD $_ST_HELM_NAME . $_ST_HELM_ARGS | $_ST_HELM_PIPE

    if [[ -z "$_ARG_DRYRUN" ]]; then
        kubectl wait --for condition=ready --all pod --namespace kube-system --timeout 5m
        sc_heading 2 "Setting up policies..."
        helm upgrade cilium . --namespace kube-system --reuse-values --set global.setupPolicies=true
    fi
fi
