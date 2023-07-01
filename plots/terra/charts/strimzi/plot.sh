#!/usr/bin/env bash
########################################################################################################################
# TERRA STRIMZI
########################################################################################################################
_SERVICE=terra-strimzi
_ORDINAL="08"

_IMAGE=-
_TAG=-

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# UP
########################################################################################################################
if [[ -n "$_ST_CONTEXT_CLUSTER" ]]; then
    if [[ " $* " =~ " up " ]]; then
        if [[ -n "$_ARG_SETUP" ]]; then
            sc_heading 1 "Setting up $_SERVICE"
            if [[ -z "$_ARG_DRYRUN" ]]; then
                argocd app sync "$_SERVICE"
                argocd app wait "$_SERVICE" --health
            else
                _cluster_domain=$(sc_context_cluster_domain)
                helm template . \
                    --set "global.clusterDomain=$_cluster_domain" \
                    --set "kafdrop.enabled=true" | yq eval '.' -
            fi
        fi
    elif [[ " $* " =~ " down " ]]; then
        argocd app delete "$_SERVICE"
    fi
fi
