#!/usr/bin/env bash
########################################################################################################################
# TERRA HTTPS
########################################################################################################################
_SERVICE=terra-https
_ORDINAL="04"

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
            argocd app sync terra-https
            argocd app wait terra-https --health
        fi
    fi
fi
