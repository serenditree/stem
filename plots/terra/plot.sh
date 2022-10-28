#!/usr/bin/env bash
########################################################################################################################
# TERRA
########################################################################################################################
_SERVICE=terra-base
_ORDINAL="00"

_IMAGE=-
_TAG=-

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# UP
########################################################################################################################
if [[ " $* " =~ " up " ]] && [[ -n "$_ST_CONTEXT_CLUSTER" ]]; then
    if [[ -n "${_ST_CONTEXT_KUBERNETES_LOCAL}" ]]; then
        source ./local/kubernetes.sh
        sc_kubernetes_local_up
    elif [[ -n "${_ST_CONTEXT_OPENSHIFT_LOCAL}" ]]; then
        source ./local/openshift.sh
        if [[ -n "$_ARG_SETUP" ]]; then
            sc_openshift_local
        else
            sc_openshift_local_up
        fi
    elif [[ -n "${_ST_CONTEXT_IS_REMOTE}" ]]; then
        sc_heading 1 "Setting up $_SERVICE"
        if [[ -z "$_ARG_DRYRUN" ]]; then
            source ./terra.sh
            sc_terra_up
            if [[ -z "${_ARG_INIT}${_ARG_UPGRADE}${_ST_CONTEXT_IS_LOCAL}" ]]; then
                sc_setup_project
                sc_setup_helm
            fi
        fi
    fi
########################################################################################################################
# DOWN
########################################################################################################################
elif [[ " $* " =~ " down " ]] && [[ -n "$_ST_CONTEXT_CLUSTER" ]]; then
    if [[ -n "${_ST_CONTEXT_KUBERNETES_LOCAL}" ]]; then
        source ./local/kubernetes.sh
        if [[ -n "${_ARG_RESET}" ]]; then
            sc_kubernetes_local_reset
        else
            sc_kubernetes_local_down
        fi
    elif [[ -n "$_ST_CONTEXT_OPENSHIFT_LOCAL" ]]; then
        source ./local/openshift.sh
        sc_openshift_local_down
    elif [[ -n "${_ST_CONTEXT_IS_REMOTE}" ]]; then
        source ./terra.sh
        sc_prompt "Delete cluster?" sc_terra_down
        sc_heading 2 "Cluster removed"
    fi
fi
