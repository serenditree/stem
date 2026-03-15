#!/usr/bin/env bash
########################################################################################################################
# Patch storage class
########################################################################################################################
kubectl patch storageclass exoscale-sbs \
    --namespace kube-system \
    --patch '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
if [[ -z "$CNI" ]]; then
########################################################################################################################
# Create IPsec secret
########################################################################################################################
    kubectl create secret generic cilium-ipsec-key \
        --from-literal key="3+ rfc4106(gcm(aes)) $(openssl rand -hex 20) 128" \
        --namespace kube-system
fi
