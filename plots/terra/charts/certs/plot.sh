#!/usr/bin/env bash
########################################################################################################################
# TERRA CERTS
########################################################################################################################
_SERVICE=terra-certs
_ORDINAL=8

_IMAGE=-
_TAG=-

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# UP
########################################################################################################################
if [[ " $* " =~ " up " ]] && [[ -n "$_ST_CONTEXT_CLUSTER" ]]; then
    if [[ -n "$_ARG_SETUP" ]]; then
        sc_heading 1 "Setting up $_SERVICE"
        if [[ -z "$_ARG_DRYRUN" ]]; then
            argocd app sync $_SERVICE
            argocd app wait $_SERVICE --health
            argocd app set $_SERVICE --parameter setupIssuer=true
            argocd app sync $_SERVICE
            argocd app wait $_SERVICE --health
        fi
    fi
fi
