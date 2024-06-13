#!/usr/bin/env bash
########################################################################################################################
# TERRA ARGOCD
########################################################################################################################
_SERVICE=terra-prometheus
_ORDINAL="5"

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
    helm install monitoring --namespace monitoring --create-namespace .
    echo "Waiting for pods to become ready..."
    kubectl wait --for condition=established --all crd
    kubectl -n monitoring wait --for=condition=ready --all pod --timeout 420s
    echo "Configuring cilium/hubble service monitors..."
    cilium upgrade --reuse-values \
        --set hubble.metrics.serviceMonitor.enabled=true \
        --set prometheus.serviceMonitor.enabled=true \
        --set operator.prometheus.serviceMonitor.enabled=true
fi
