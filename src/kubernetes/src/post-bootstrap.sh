#!/usr/bin/env bash
########################################################################################################################
# Wait for nodes
########################################################################################################################
echo "Waiting for nodes..."
until kubectl wait --for condition=ready --all node 2>/dev/null; do sleep 1s; done
########################################################################################################################
# Update admin password
########################################################################################################################
ARGOCD_INITIAL_PASSWORD="$(
    kubectl get secret/argocd-initial-admin-secret \
        --namespace terra-argocd  \
        --output jsonpath='{.data.password}' | base64 --decode
)"
ARGOCD_NEW_PASSWORD="$(pass serenditree/cicd/terraArgocd.password)"

kubectl port-forward --namespace terra-argocd svc/terra-argocd-server 9098:443 &>/tmp/argocd-server.log &
sleep 2s

argocd login localhost:9098 \
    --insecure \
    --username admin \
    --password "$ARGOCD_INITIAL_PASSWORD"

argocd account update-password \
    --account admin \
    --current-password "$ARGOCD_INITIAL_PASSWORD" \
    --new-password "$ARGOCD_NEW_PASSWORD"
########################################################################################################################
# Add git repository
########################################################################################################################
argocd repo add "$_ST_GIT" \
    --ssh-private-key-path "$_ST_GIT_SSH" \
    --project default \
    --name serenditree-stem
