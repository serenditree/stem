#!/usr/bin/env bash
########################################################################################################################
# TERRA ARGOCD
########################################################################################################################
_SERVICE=terra-argocd
_ORDINAL=2

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
    _cluster_domain=$(sc_context_cluster_domain)
    _github_token=$(pass serenditree/github.com)
    _quay_token=$(pass serenditree/quay.io)
    _redhat_token=$(pass serenditree/registry.redhat.io)
    _argocd_password="$(pass serenditree/argocd)"
    _argocd_password_bcrypt="$(htpasswd -nbBC 10 "" "$_argocd_password" | tr -d ':\n' | sed 's/$2y/$2a/')"

    [[ -z "$_ARG_DRYRUN" ]] && _ST_HELM_NAME=argocd
    helm $_ST_HELM_CMD $_ST_HELM_NAME . \
        --namespace argocd \
        --create-namespace \
        --set "argo-cd.configs.secret.argocdServerAdminPassword=$_argocd_password_bcrypt" \
        --set "global.context=$_ST_CONTEXT" \
        --set "global.clusterDomain=$_cluster_domain" \
        --set "ingress.letsencrypt.issuer=$_ARG_ISSUER" \
        --set "ingress.letsencrypt.email=$(pass serenditree/contact)" \
        --set "tekton.basic.github=${_github_token#*:}" \
        --set "tekton.basic.quay=${_quay_token#*:}" \
        --set "tekton.basic.redhat=${_redhat_token#*:}" | $_ST_HELM_PIPE

    if [[ -z "${_ARG_DRYRUN}${_ARG_UPGRADE}" ]]; then
        sc_heading 2 "Waiting for custom resources to become established..."
        kubectl wait --for condition=established --all crd --namespace argocd
        sc_heading 2 "Waiting for pods to become ready..."
        kubectl wait --for condition=available --all deployment --namespace argocd
        kubectl rollout status sts argocd-application-controller --watch --namespace argocd
        sc_heading 2 "Starting port-forwarding..."
        kubectl port-forward --namespace argocd svc/argocd-server 9098:443 &>/tmp/nohup-port-fwd.log &
        sleep 3s
        sc_heading 2 "ArgoCD login..."
        argocd login localhost:9098 \
            --insecure \
            --name serenditree \
            --username admin \
            --password "$_argocd_password"
        sc_heading 2 "Adding git repository..."
        argocd repo add git@github.com:serenditree/stem.git \
            --ssh-private-key-path ~/.ssh/stem@serenditree.io \
            --name stem
        sc_heading 2 "Patching ArgoCD config map..."
        sc_cluster_patch argocd-cm

        sc_heading 2 "Installing apps..."
        if [[ -z "$_ARG_DRYRUN" ]]; then
            helm upgrade $_ST_HELM_NAME . \
                --namespace argocd \
                --reuse-values \
                --set "global.setupApps=true"
        else
            helm template . \
                --namespace argocd \
                --reuse-values \
                --set "global.setupApps=true" | yq eval
        fi
        sc_heading 2 "Re-login..."
        argocd relogin --password "$_argocd_password"
    fi
fi
