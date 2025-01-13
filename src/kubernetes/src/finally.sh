#!/usr/bin/env bash
########################################################################################################################
# Wait for load-balancer IP
########################################################################################################################
echo "Waiting for load-balancer..."
until exo compute nlb list --output-template '{{.Name}}' | grep -q 'serenditree'; do sleep 1s; done
until [[ -n "$_NLB_IP" ]] && [[ "$_NLB_IP" != "<nil>" ]]; do
    _NLB_IP=$(exo compute nlb show 'serenditree' --output-format json | jq -r '.ip_address')
    sleep 1s
done
########################################################################################################################
# Set up DNS records
########################################################################################################################
exo dns add A "$_ST_DOMAIN" --name "" --address "$_NLB_IP"
exo dns add CNAME "$_ST_DOMAIN" --name "www" --alias "$_ST_DOMAIN"
exo dns show "$_ST_DOMAIN" --output-template "{{.ID}};{{.Name}};{{.RecordType}};{{.Content}};{{.TTL}}" |
    sort -t ';' -k 3 |
    column -ts ';'
