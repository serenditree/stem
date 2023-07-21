#!/usr/bin/env bash
########################################################################################################################
# TERRA ARGOCD
########################################################################################################################
_SERVICE=terra-argocd
_ORDINAL="01"

_IMAGE=-
_TAG=-

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# UP
########################################################################################################################
if [[ " $* " =~ " up " ]] && [[ -n "$_ST_CONTEXT_CLUSTER" ]] && [[ -n "${_ARG_SETUP}${_ARG_UPGRADE}" ]]; then
    sc_heading 1 "Setting up $_SERVICE"
    if [[ -z "${_ARG_DRYRUN}${_ARG_UPGRADE}" ]]; then
        kubectl create namespace argocd
        kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
        echo "Waiting for argocd..."
        sleep 30s
        kubectl wait --for condition=ready --all pod --namespace argocd --timeout 5m
        echo "Patching argocd config map..."
        sc_cluster_patch argocd-cm
        echo "Starting port-forwarding..."
        kubectl port-forward --namespace argocd svc/argocd-server 9098:443 &>/tmp/nohup-port-fwd.log &
        sleep 3s

        _argocd_password="$(pass serenditree/argocd)"
        _secret="$(kubectl get secret/argocd-initial-admin-secret \
            --namespace argocd  \
            -o jsonpath='{.data.password}' | \
            base64 --decode)"

        argocd login localhost:9098 --insecure --username admin --password "$_secret"
        argocd account update-password --account admin --new-password "$_argocd_password" --current-password "$_secret"
        argocd repo add git@github.com:serenditree/stem.git \
            --ssh-private-key-path ~/.ssh/stem@serenditree.io \
            --name stem
    fi

    _cluster_domain=$(sc_context_cluster_domain)
    _apisix_admin=$(pass serenditree/apisix.admin)
    _github_token=$(pass serenditree/github.com)
    _quay_token=$(pass serenditree/quay.io)
    _redhat_token=$(pass serenditree/registry.redhat.io)

    [[ -z "$_ARG_DRYRUN" ]] && _ST_HELM_NAME=argocd
    helm $_ST_HELM_CMD $_ST_HELM_NAME . \
        --set "global.context=$_ST_CONTEXT" \
        --set "global.clusterDomain=$_cluster_domain" \
        --set "apisix.admin.credentials.admin=${_apisix_admin#*:}" \
        --set "apisix.admin.credentials.viewer=$(pass serenditree/apisix.viewer)" \
        --set "apisix.dashboard.secret=$(pass serenditree/json.web.key)" \
        --set "apisix.dashboard.username=${_apisix_admin%:*}" \
        --set "apisix.dashboard.password=${_apisix_admin#*:}" \
        --set "ingress.letsencrypt.issuer=$_ARG_ISSUER" \
        --set "ingress.letsencrypt.email=$(pass serenditree/contact)" \
        --set "tekton.basic.github=${_github_token#*:}" \
        --set "tekton.basic.quay=${_quay_token#*:}" \
        --set "tekton.basic.redhat=${_redhat_token#*:}" | $_ST_HELM_PIPE
fi
