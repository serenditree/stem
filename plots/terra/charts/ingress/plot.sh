#!/usr/bin/env bash
########################################################################################################################
# TERRA INGRESS
########################################################################################################################
_SERVICE=terra-ingress
_ORDINAL=4

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
        argocd app sync $_SERVICE
        argocd app wait $_SERVICE --health

        echo "Waiting for load-balancer..."
        until [[ $(exo compute nlb list --output-template '{{.Name}}' | grep -c 'serenditree') -gt 0 ]]; do
            sleep 1s
        done
        until [[ -n "$_nlb_ip" ]] && [[ "$_nlb_ip" != "<nil>" ]]; do
            _nlb_ip=$(exo compute nlb show 'serenditree' --output-format json | jq -r '.ip_address')
            sleep 1s
        done
        echo "Load-balancer IP: ${_nlb_ip}"

        sc_heading 1 "Setting up dns records..."
        exo dns add A "$_ST_DOMAIN" --name "" --address "$_nlb_ip"
        exo dns add CNAME "$_ST_DOMAIN" --name "www" --alias "$_ST_DOMAIN"
        exo dns show "$_ST_DOMAIN" --output-template "{{.ID}};{{.Name}};{{.RecordType}};{{.Content}};{{.TTL}}" |
            sort -t ';' -k 3 |
            column -ts ';'
    fi
fi
