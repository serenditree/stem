#!/usr/bin/env bash
########################################################################################################################
# TERRA ARGOCD
########################################################################################################################
_SERVICE=terra-apisix
_ORDINAL="01"

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
#    cd /home/tanwald/Development/Serenditree/stem/plots/terra/charts/apisix
#    minikube start -p serenditree-kubernetes-apisix
#    kubectl config use-context serenditree-kubernetes-apisix
#
#    helm install --namespace prometheus --create-namespace prometheus prometheus/kube-prometheus-stack
#    kubectl --namespace prometheus get pods -l "release=prometheus"
#    helm install --namespace apisix --create-namespace apisix .
fi
