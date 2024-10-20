#!/usr/bin/env bash
########################################################################################################################
# TERRA-SCALE
########################################################################################################################
_SERVICE=terra-scale
_ORDINAL=5

_IMAGE=-
_TAG=-

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL}* ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# UP
########################################################################################################################
if [[ " $* " =~ " up " ]] && [[ -n "$_ST_CONTEXT_CLUSTER" ]] && [[ -n "$_ARG_SETUP" ]]; then
    sc_heading 1 "Setting up ${_SERVICE}"
    if [[ -z "$_ARG_DRYRUN" ]]; then
        sc_heading 2 "Creating secret for autoscaler..."
        kubectl create secret generic "${_SERVICE}-exoscale-cluster-autoscaler" \
            --namespace kube-system \
            --from-literal=api-key="$(pass serenditree/scaler@exoscale.com.access)" \
            --from-literal=api-secret="$(pass serenditree/scaler@exoscale.com.secret)" \
            --from-literal=api-zone="${_ST_ZONE}"

        _autoscaling_groups=
        _index=0
        for _name in $(exo compute instance-pool list --output-template '{{.Name}}'); do
            _value="--parameter cluster-autoscaler.autoscalingGroups[${_index}]"
            _autoscaling_groups+="${_value}.name=${_name} ${_value}.minSize=3 ${_value}.maxSize=6 "
            ((_index++))
        done

        sc_heading 2 "Setting autoscaling groups"
        echo "$_autoscaling_groups" | xargs argocd app set $_SERVICE

        sc_heading 2 "Starting sync..."
        argocd app sync $_SERVICE
        argocd app wait $_SERVICE --health
    fi
fi
