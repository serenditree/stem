#!/usr/bin/env bash
########################################################################################################################
# TERRA
########################################################################################################################
_SERVICE=terra-cilium
_ORDINAL=1

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
        _ipsec_key="$(dd if=/dev/urandom count=20 bs=1 2> /dev/null | xxd -p -c 64)"
        _ipsec_key_secret=cilium-ipsec-keys

        kubectl create secret generic $_ipsec_key_secret \
            --namespace kube-system \
            --from-literal=keys="3+ rfc4106(gcm(aes)) $_ipsec_key 128"

        _cluster_domain="$(sc_context_cluster_domain)"
        _metrics="dns,drop,tcp,flow,port-distribution,icmp,"
        _metrics+="httpV2:exemplars=true;labelsContext=source_namespace\,source_app\,source_ip\,"
        _metrics+="destination_namespace\,destination_app\,destination_ip\,traffic_direction"

        cilium install \
            --set etcd.clusterDomain="$_cluster_domain" \
            --set hubble.peerService.clusterDomain="$_cluster_domain" \
            --set encryption.enabled="true" \
            --set encryption.type="ipsec" \
            --set encryption.ipsec.secretName="${_ipsec_key_secret}" \
            --set prometheus.enabled="true" \
            --set operator.prometheus.enabled="true" \
            --set hubble.enabled="true" \
            --set hubble.relay.enabled="true" \
            --set hubble.ui.enabled="true" \
            --set hubble.metrics.enableOpenMetrics="true" \
            --set hubble.metrics.enabled="{${_metrics}}"

        cilium status --wait

        kubectl -n kube-system rollout restart ds exoscale-csi-node
        kubectl -n kube-system rollout status ds exoscale-csi-node --watch
    fi
fi
