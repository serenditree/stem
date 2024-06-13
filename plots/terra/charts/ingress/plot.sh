#!/usr/bin/env bash
########################################################################################################################
# TERRA CACHE
########################################################################################################################
_SERVICE=terra-ingress
_ORDINAL="3"

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
            echo "Checking preconditions for ingress setup..."
            if [[ $(exo compute nlb list | wc -l) -gt 0 ]]; then
                echo "Found existing load-balancer. Aborting..."
                exit 1
            fi
            argocd app sync $_SERVICE
            argocd app wait $_SERVICE --health

            echo "Waiting for load-balancer..."
            until [[ $(exo compute nlb list | wc -l) -gt 0 ]]; do
                sleep 1s
            done
            _nlb_id="$(exo compute nlb list --output-template '{{.ID}}')"
            echo "Load-balancer ID: ${_nlb_id}"
            until [[ -n "$_nlb_ip" ]] && [[ "$_nlb_ip" != "<nil>" ]]; do
                _nlb_ip=$(exo compute nlb show "$_nlb_id" --output-format json | jq -r '.ip_address')
                sleep 1s
            done
            echo "Load-balancer IP: ${_nlb_ip}"
            echo "Updating load-balancer name..."
            exo compute nlb update "${_nlb_id}" --name serenditree

            sc_heading 1 "Setting up dns records..."
            exo dns add A "serenditree.io" --name "" --address "$_nlb_ip"
            exo dns add CNAME "serenditree.io" --name "www" --alias "serenditree.io"
            exo dns show "serenditree.io" --output-template "{{.ID}};{{.Name}};{{.RecordType}};{{.Content}};{{.TTL}}" |
                sort -t ';' -k 3 |
                column -ts ';'
        fi
    fi
fi
