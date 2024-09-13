#!/usr/bin/env bash
########################################################################################################################
# TERRA TEKTON
########################################################################################################################
_SERVICE=terra-tekton
_ORDINAL=5

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
        kubectl create namespace tekton-pipelines
        kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
        echo "Waiting for tekton..."
        kubectl wait --for condition=ready --all pod --namespace tekton-pipelines --timeout 5m

        sc_heading 2 "Creating tekton resources"
        helm dependency build
        argocd app sync terra-tekton
        argocd app wait terra-tekton --health

        sc_heading 2 "Patching tekton service account..."
        kubectl patch serviceaccount pipelines \
            --patch-file="${_ST_HOME_STEM}/rc/patches/tekton-sa.yaml" \
            --namespace tekton-pipelines

        sc_heading 2 "Removing enforce-label from namespace..."
        kubectl label namespaces tekton-pipelines pod-security.kubernetes.io/enforce-
    fi
fi
