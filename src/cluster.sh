#!/usr/bin/env bash
########################################################################################################################
# CLUSTER FUNCTIONS
# Functions for the interaction with kubernetes clusters.
########################################################################################################################

function sc_cluster_deploy() {
    local -r _args=$1
    local _apps
    sc_login argocd
    for _app in branch leaf; do
        if [[ "$_app" =~ $_args ]]; then
            if [[ -n "$_ARG_YES" ]] || sc_prompt "Deploy ${_app}?" echo -n; then
                sc_heading 2 "Deployment of $_app started..."
                argocd app actions run --all --kind Deployment $_app restart
                _apps+=" $_app"
            fi
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

    echo -en "\nChecking control plane..."
    local -r _status="$(kubectl --context $_ST_CONTEXT api-resources $_request_timeout 2>&1 | grep -Eom1 'true')"
    if [[ "$_status" == "true" ]]; then
        sc_heading 2 "up"

        echo -en "Checking nodes..."
        local -r _nodes=$(kubectl get node --no-headers | wc -l)
        local -r _ready=$(kubectl get node --no-headers | grep -c ' Ready ')
        if [[ $_ready -eq $_nodes ]]; then
            sc_heading 2 "ok"
            local -r _cluster_ready=0
        else
            echo "${_BOLD}warning:${_NORMAL} ${_ready}/${_nodes} nodes ready"
            local -r _cluster_ready=1
        fi
    else
        sc_heading 2 "down"
        local -r _cluster_ready=1
    fi

    return $_cluster_ready
}
export -f sc_cluster_status

# Creates a secret for backup/restore-jobs.
function sc_cluster_backup_restore_secret() {
    trap 'rm -f /tmp/exoscale.toml' EXIT
    local -r _secret="/tmp/exoscale.toml"
    if ! kubectl get secret exoscale-backup --namespace serenditree &>/dev/null; then
        sed -E \
            -e "s/<KEY>/$(pass serenditree/backup@exoscale.com.access)/" \
            -e "s/<SECRET>/$(pass serenditree/backup@exoscale.com.secret)/" \
            -e "s/<ZONE>/${_ST_ZONE}/" \
            "${_ST_HOME_STEM}/rc/templates/exoscale.toml" >"$_secret"
        kubectl create secret generic exoscale-backup --namespace serenditree --from-file="$_secret"
    fi
}

# Restores databases.
function sc_cluster_restore() {
    sc_cluster_backup_restore_secret
    for _comp in user seed; do
        kubectl create --filename "${_ST_HOME_STEM}/rc/jobs/${_comp}-restore.yml" --namespace serenditree
    done
}

# Creates cronjobs or jobs for database backups.
function sc_cluster_backup() {
    sc_cluster_backup_restore_secret
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

# Prints resource allocations.
function sc_cluster_resources() {
    local -r _csv=$1
    local -r _tmp=/tmp/serenditree-nodes
    sc_heading 1 "Cluster resource allocation"
    if [[ "$_csv" == "csv" ]]; then
        local _pipe="tee"
    else
        local _pipe="column -ts ';'"
    fi
    kubectl describe node >$_tmp
    cat \
        <(echo "NAMESPACE;NAME;CPU REQUESTS;CPU LIMITS;MEMORY REQUESTS;MEMORY LIMITS") \
        <(sed -n '/Non-terminated Pods/,/Allocated resources/p' $_tmp |
              sed '0,/--/{/--/d;}' |
              sed -E -e '/(Allocated|Non|Namespace)/d' \
                  -e 's/([0-9]+)(m|Mi)/\1/g' \
                  -e 's/([0-9]+)Gi/\1000/g' \
                  -e 's/\s([1-9])\s/ \1000 /g' \
                  -e 's/\([^)]+\)//g' \
                  -e 's/\s\w+$//' \
                  -e 's/\s+$//' \
                  -e 's/^\s+//' \
                  -e 's/--+.*/;;;;;/' \
                  -e 's/\s+/;/g') |
        $_pipe

    sc_heading 1 "Cluster resource allocation summary"
    cat \
        <(echo "RESOURCE;REQUESTS;PERCENT;LIMITS;PERCENT") \
        <(sed -n '/Allocated resources/,/Events:/p' $_tmp |
            sed -En '/(cpu|memory)/p' |
            sed -E  -e 's/[()]//g' -e 's/\s+$//' -e 's/^\s+//' -e 's/\s+/;/g' |
            awk 'NR % 2 == 1 {print} NR % 2 == 0 {print $0 "\n;;;;"}') |
        head -n -1 |
        $_pipe

    sc_heading 1 "Cluster cpu and memory"
    cat \
        <(echo "CPU;MEMORY;") \
        <(paste \
            <(sed -En 's/\s+cpu:\s+(\S+)/\1/p' $_tmp) \
            <(sed -En 's/\s+memory:\s+([0-9]+).*/\1/p' $_tmp | awk '{print $1 / 1000}') |
                sed -E  -e 's/\s+$//' -e 's/^\s+//' -e 's/\s+/;/g' |
                awk 'NR % 2 == 1 {print $0 "Mi;capacity"} NR % 2 == 0 {print $0 "Mi;allocatable\n;;"}') |
        head -n -1 |
        $_pipe
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
    # Completed pods except the two most recent ones.
    kubectl get pod \
        --namespace serenditree \
        --field-selector='status.phase==Succeeded' \
        --sort-by '{.metadata.creationTimestamp}' \
        --output=custom-columns='Name:.metadata.name' \
        --no-headers |
        head -n -2 |
        xargs --no-run-if-empty kubectl --namespace serenditree delete pod
    # Orphaned replica sets.
    kubectl get rs \
        --namespace serenditree \
        --output=jsonpath='{.items[?(@.spec.replicas==0)].metadata.name}' |
        xargs --no-run-if-empty kubectl --namespace serenditree delete rs
    # Pipeline runs except the two most recent ones.
    tkn pipelinerun delete --keep 2 --namespace tekton-pipelines
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
    echo -e "kubectl listening on ports: $_used_ports\n" | tr '|' ' '

    local -r _logs=/tmp/nohup-port-fwd.log
    for _svc in argocd/svc/argocd-server~9098:443 \
        kube-system/svc/hubble-ui~9080:80 \
        strimzi/svc/kafdrop~9000:9000 \
        tekton-pipelines/svc/tekton-dashboard~9097:9097; do
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
                echo "${_svc} ${_BOLD}up${_NORMAL}"
            else
                if kubectl get --namespace $_namespace $_svc &>/dev/null; then
                    echo "Port-forwarding ${_svc}..."
                    nohup kubectl port-forward $_svc $_ports --namespace $_namespace &>$_logs &
                    _used_ports+="${_ports%:*}"
                else
                    echo "$_svc ${_BOLD}unavailable${_NORMAL}"
                fi
            fi
        fi
    done
    [[ "$_used_ports" != "none" ]] && echo -e "\nCheck logs in ${_logs}!"
}

# Starts or stops the cluster.
# $1: Start or stop
function sc_cluster_toggle() {
    local -r _toggle=$1
    for _instance in $(exo compute instance list --zone "$_ST_ZONE" --output-template '{{.ID}}'); do
        exo compute instance "$_toggle" "$_instance" --force --output-format json | jq
    done
    if [[ "$_toggle" == "start" ]] && [[ -n "$_ARG_WATCH" ]]; then
        local -r _lines=$(kubectl get pod --all-namespaces | wc -l)
        tput civis
        trap "tput cnorm && tput cud $_lines" EXIT
        while kubectl get pod --all-namespaces; do
            sleep 2s
            tput cuu $_lines
        done
    fi
}
