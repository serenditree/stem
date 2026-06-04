#!/usr/bin/env bash
########################################################################################################################
# Patch storage class
########################################################################################################################
kubectl patch storageclass exoscale-sbs \
    --namespace kube-system \
    --patch '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
########################################################################################################################
# Install CRDs
########################################################################################################################
kubectl apply --server-side --filename "$CRDS"
kubectl apply --server-side --filename \
    https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
