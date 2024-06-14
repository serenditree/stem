#!/usr/bin/env bash
########################################################################################################################
# TERRA ARGOCD
########################################################################################################################
_SERVICE=terra-prometheus
_ORDINAL=6

_IMAGE=-
_TAG=-

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# UP
########################################################################################################################
if [[ -z "SKIP" ]] && [[ " $* " =~ " up " ]] && [[ -n "$_ST_CONTEXT_CLUSTER" ]] && [[ -n "$_ARG_SETUP" ]]; then
    sc_heading 1 "Setting up $_SERVICE"
    if [[ -z "$_ARG_DRYRUN" ]]; then
        argocd app sync $_SERVICE
        argocd app wait $_SERVICE --health
    echo "Configuring cilium service monitors..."
    cilium upgrade --reuse-values \
        --set hubble.metrics.serviceMonitor.enabled=true \
        --set prometheus.serviceMonitor.enabled=true \
        --set operator.prometheus.serviceMonitor.enabled=true
    fi
fi
