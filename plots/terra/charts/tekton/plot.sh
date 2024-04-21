#!/usr/bin/env bash
########################################################################################################################
# TERRA TEKTON
########################################################################################################################
_SERVICE=terra-tekton
_ORDINAL="3"

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
    fi
    sc_heading 1 "Setting up $_SERVICE dashboard"
    if [[ -z "$_ARG_DRYRUN" ]]; then
        kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml
        echo "Waiting for tekton dashboard..."
        kubectl wait --for condition=ready --all pod --namespace tekton-pipelines --timeout 5m
    fi
    sc_heading 1 "Creating tekton resources"
    [[ -z "$_ARG_DRYRUN" ]] && helm dependency build

    _st_github_token=$(pass serenditree/github.com)
    _st_quay_token=$(pass serenditree/quay.io)
    _st_redhat_token=$(pass serenditree/registry.redhat.io)

    [[ -z "$_ARG_DRYRUN" ]] && _ST_HELM_NAME=tekton
    helm $_ST_HELM_CMD $_ST_HELM_NAME . \
        --namespace tekton-pipelines \
        --set "basic.github=${_st_github_token#*:}" \
        --set "basic.quay=${_st_quay_token#*:}" \
        --set "basic.redhat=${_st_redhat_token#*:}" \
        --set "global.context=$_ST_CONTEXT" | $_ST_HELM_PIPE

    if [[ -z "$_ARG_DRYRUN" ]]; then
        argocd app sync terra-tekton
        argocd app wait terra-tekton --health
    fi

    if [[ -z "${_ARG_DRYRUN}${_ST_CONTEXT_IS_KUBERNETES}" ]]; then
        sc_heading 2 "Patching tekton service account..."
        kubectl patch serviceaccount pipelines \
            --patch-file="${_ST_HOME_STEM}/rc/patches/tekton-sa.yaml" \
            --namespace tekton-pipelines
    fi
fi
