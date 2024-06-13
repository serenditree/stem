#!/usr/bin/env bash
########################################################################################################################
# CLUSTER FUNCTIONS
# Functions for the interaction with kubernetes clusters.
########################################################################################################################

function sc_cluster_deploy() {
    local _apps
    for _app in branch leaf; do
        if sc_prompt "Deploy ${_app}?" argocd app actions run --all --kind Deployment $_app restart; then
            echo "Deployment of $_app started..."
            _apps+=" $_app"
        fi
    done
    [[ -n "$_apps" ]] && argocd app wait $_apps --health
}

function sc_cluster_dashboard() {
    local -r _host=localhost:8001
    echo "Opening dashboard..."
    if curl $_host &>/dev/null; then
        xdg-open \
            http://${_host}/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/login
    else
        nohup minikube dashboard \
            --profile "$_ST_CONTEXT_KUBERNETES_LOCAL" \
            --port ${_host#*:} &>/dev/null &
    fi
}

function sc_cluster_status() {
    if [[ -n "${_ST_CONTEXT_OPENSHIFT_LOCAL}${_ST_CONTEXT_KUBERNETES_LOCAL}" ]]; then
        local -r _request_timeout='--request-timeout=400ms'
    else
        local -r _request_timeout='--request-timeout=800ms'
    fi

    echo -en "\nChecking status..."
    local -r _status="$(kubectl api-resources $_request_timeout 2>&1 | grep -Eom1 'true')"
    if [[ "$_status" == "true" ]]; then
        sc_heading 2 "up"
        local -r _authenticated=0
    else
        sc_heading 2 "down"
        local -r _authenticated=1
    fi

    return $_authenticated
}
export -f sc_cluster_status

# Restores databases
function sc_cluster_restore() {
    if ! kubectl get secret exoscale-config &>/dev/null; then
        kubectl create secret generic exoscale-config --from-file="$EXOSCALE_CONFIG" --namespace serenditree
    fi
    for _comp in user seed; do
        echo kubectl create --filename "${_ST_HOME_STEM}/rc/jobs/${_comp}-restore.yml" --namespace serenditree
    done
}

# Creates cronjobs of jobs for database backups
function sc_cluster_backup() {
    if ! kubectl get secret exoscale-config &>/dev/null; then
        kubectl create secret generic exoscale-config --from-file="$EXOSCALE_CONFIG" --namespace serenditree
    fi
    for _comp in user seed; do
        if [[ -n "$_ARG_SETUP" ]]; then
            kubectl create --filename "${_ST_HOME_STEM}/rc/jobs/${_comp}-backup.yml" --namespace serenditree
        else
            kubectl create job "${_comp}-backup-$(date +%Y%m%d-%H%M%S)" \
                --from=cronjob/${_comp}-backup \
                --namespace serenditree
        fi
    done
}

# Applies predefined patches to cluster resources.
# $1: Patch to apply.
function sc_cluster_patch() {
    case $1 in
    argocd-cm)
        kubectl patch cm argocd-cm \
            --patch-file="${_ST_HOME_STEM}/rc/patches/argocd-cm.yaml" \
            --namespace argocd
        ;;
    recreate)
        # Patch deployment strategy for low performance environments.
        kubectl get deploy --namespace serenditree --no-headers --selector app.kubernetes.io/part-of=serenditree |
            cut -d' ' -f1 |
            xargs -I{} kubectl patch deploy {} --patch-file="${_ST_HOME_STEM}/rc/patches/global-recreate.yaml"
        ;;
    esac
}
export -f sc_cluster_patch

# Prints and follows logs of the given service.
function sc_cluster_logs() {
    kubectl get pods --no-headers -l name=$1 | cut -d' ' -f1 | xargs kubectl logs -f
}

# Prints all resources of interest (more than 'get all').
function sc_cluster_resources() {
    local _resources='sa,pv,pvc,cm,secrets,sts,deploy,svc,po,clustertasks,tasks,pipelines,k,kt'
    if [[ -n "${_ST_CONTEXT_IS_OPENSHIFT}" ]]; then
        _resources+=',dc,is,istag'
    fi
    kubectl get --namespace serenditree $_resources
}

# Prints certificate information.
function sc_cluster_certificate() {
    local _cert='serenditree-tls-prod'
    if [[ "$_ST_STAGE" == "dev" ]]; then
        _cert='serenditree-tls-staging'
    else
        _cert='serenditree-tls-prod'
    fi

    sc_heading 1 "Certificate"
    kubectl get certificate $_cert --namespace serenditree --output yaml
    sc_heading 1 "Secret"
    kubectl get secrets $_cert --namespace serenditree --output yaml
    sc_heading 1 "Certificate info"
    kubectl get secrets $_cert --namespace serenditree --output json |
        jq -r '.data."tls.crt"' |
        base64 --decode |
        #sed -n '0,/--END/p' |
        openssl x509 -noout -text
}

# Deletes dispensable resources.
function sc_cluster_clean() {
    kubectl delete pod --namespace serenditree --field-selector status.phase==Succeeded
    kubectl get rs | grep -E '(0\s+){3}' | cut -d' ' -f1 | xargs kubectl delete rs
}

# Inspects all or defined images of the OpenShift registry.
# $1: Optional list of image names.
function sc_cluster_registry() {
    local -r _images=$(sc_args_to_pattern "$*")

    oc get is --no-headers |
        grep -Ei "${_images}" |
        cut -d' ' -f1 |
        xargs -I{} bash -c "sc_heading 1 serenditree/{} &&
            skopeo inspect --tls-verify=false docker://${_ST_REGISTRY}/serenditree/{}"
}

# Port-forwarding for management dashboards.
# $1: Pattern for service selection
function sc_cluster_expose() {
    local -r _pattern=$1
    local _used_ports

    _used_ports="$(netstat --inet -tlnp 2>&1 |
        sed -En 's/.*127.0.0.1:([0-9]+).*kubectl/\1/p' |
        xargs echo |
        tr ' ' '|')"
    [[ -n "$_used_ports" ]] || _used_ports='none'
    echo "kubectl listening on ports: $_used_ports" | tr '|' ' '

    local -r _logs=/tmp/nohup-port-fwd.log
    for _svc in argocd/svc/argocd-server~9098:443 \
        strimzi/svc/kafdrop~9000:9000 \
        tekton-pipelines/svc/tekton-dashboard~9097:9097 \
        longhorn-system/svc/longhorn-frontend~8000:80; do
        if [[ $_svc =~ $_pattern ]]; then
            local _ports="${_svc#*~}"
            local _path="${_svc%~*}"
            local _namespace="${_path%%/*}"
            local _svc="${_path#*/}"
            if [[ -n "$_ARG_DELETE" ]]; then
                netstat --inet -tlnp 2>&1 |
                    sed -En "s/.*127.0.0.1:${_ports%:*}.* ([0-9]+)\/kubectl/\1/p" |
                    xargs kill &>/dev/null && echo "${_svc} terminated"
            elif [[ ${_ports%:*} =~ $_used_ports ]]; then
                echo "${_svc} up"
            else
                if kubectl get namespace $_namespace &>/dev/null; then
                    echo "Port-forwarding ${_svc}..."
                    nohup kubectl port-forward $_svc $_ports --namespace $_namespace &>$_logs &
                    _used_ports+="${_ports%:*}"
                else
                    echo "$_path unavailable."
                fi
            fi
        fi
    done
    [[ "$_used_ports" != "none" ]] && echo "Check logs in ${_logs}!"
}
