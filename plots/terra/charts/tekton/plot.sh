#!/usr/bin/env bash
########################################################################################################################
# TERRA TEKTON
########################################################################################################################
_SERVICE=terra-tekton
_ORDINAL=7

_IMAGE=-
_TAG=-

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL}* ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# UP
########################################################################################################################
if [[ " $* " =~ " up " ]] && [[ -n "$_ST_CONTEXT_CLUSTER" ]] && [[ -n "$_ARG_SETUP" ]]; then
    sc_heading 1 "Setting up $_SERVICE"
    if [[ -z "$_ARG_DRYRUN" ]]; then
        curl -s https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml |
            sed -E  -e "/kind: Namespace/,/---/ s/(name: )tekton-pipelines/\1${_SERVICE}/g" \
                    -e "s/(namespace: )tekton-pipelines/\1${_SERVICE}/g" |
            kubectl apply -f -
        echo "Waiting for tekton..."
        kubectl wait --for condition=ready --all pod --namespace $_SERVICE --timeout 5m

        sc_heading 2 "Creating tekton resources"
        helm dependency build
        argocd app sync $_SERVICE
        argocd app wait $_SERVICE --health

        sc_heading 2 "Patching tekton service account..."
        kubectl patch serviceaccount tekton-pipelines-controller \
            --patch-file="${_ST_HOME_STEM}/rc/patches/tekton-sa.yaml" \
            --namespace $_SERVICE

        sc_heading 2 "Removing enforce-label from namespace..."
        kubectl label namespaces $_SERVICE pod-security.kubernetes.io/enforce-
    fi
fi
