#!/usr/bin/env bash
########################################################################################################################
# SETUP
# Global setup tasks.
########################################################################################################################

# Checks if the project is already set up and creates the namespace if necessary.
function sc_setup_project() {
    sc_heading 1 "Setting up project namespace"

    echo -n "Checking cluster status..."
    if [[ -z "$_ARG_DRYRUN" ]]; then
        if sc_cluster_status &>/dev/null; then
            sc_heading 2 "up"

            echo -n "Checking namespace..."
            if ! kubectl get namespace serenditree &>/dev/null; then
                kubectl create namespace serenditree ||
                    { echo "Could not create project. Please login first." && exit 1; }
            else
                sc_heading 2 "set"
            fi
        else
            sc_heading 2 "down"
            echo "Aborting..." && exit 1
        fi
    else
        sc_heading 2 "skipped"
    fi
}
export -f sc_setup_project

# Helm dependency init and repo setup.
function sc_setup_helm() {
    sc_heading 1 "Setting up helm"

    if [[ -z "$_ARG_DRYRUN" ]]; then
        echo "Adding repos..."
        for _repo in \
            bitnami:https://charts.bitnami.com/bitnami \
            strimzi:https://strimzi.io/charts \
            prometheus:https://prometheus-community.github.io/helm-charts \
            cert-manager:https://charts.jetstack.io; do
            echo -n "${_repo%%:*}..."
            if helm repo ls | grep -Eq "^${_repo%%:*}"; then
                sc_heading 2 "set"
            else
                helm repo add "${_repo%%:*}" "${_repo#*:}"
            fi
        done
        echo "Updating dependencies..."
        local _refresh
        while read -r _chart; do
            if grep -q 'https://' $_chart; then
                dirname "$_chart" | xargs helm dependency update $_refresh
                _refresh=--skip-refresh
            fi
        done < <(find $_SC_HOME_STEM -name Chart.yaml)
    fi
}
export -f sc_setup_helm

# Helm dependency version update check.
function sc_setup_helm_update() {
    #helm repo update
    for _repo in \
        bitnami/mongodb \
        bitnami/mariadb-galera \
        strimzi/strimzi-kafka-operator \
        prometheus/kube-prometheus-stack \
        cert-manager/cert-manager; do
        { \
        echo "id: $_repo"
        # current version
        find $_SC_HOME_STEM -name Chart.yaml -exec grep -hA2 "name: ${_repo#*/}" {} \+ |
            sed -r -e 's/^[- ]+//' |
            sed -r '/^$/d'
        echo -n 'latest: '
        helm search repo $_repo --output json | jq -r '.[0] | .version'; \
        } | column -t -s ':' -l 2 && echo
    done
    echo "details: helm search repo ID --output json"
}

# Updates base images or checks for upgrades.
function sc_setup_image_update() {
    if [[ -n "$_ARG_UPGRADE" ]]; then
        env | grep "_ST_FROM_" | cut -d'=' -f2 | while read -r _image; do
            sc_heading 2 "$_image"
            skopeo inspect docker://${_image%:*} |
                jq -r '.RepoTags[]' |
                sort -V |
                sed -rn '/^[[:digit:]]+\.[[:digit:]]+\.?[[:digit:]]*$/p' |
                tail -n5
        done
    else
        env | grep "_ST_FROM_" | cut -d'=' -f2 | xargs podman pull
    fi
}

function sc_setup_maven_update() {
    pushd "$_ST_HOME_BRANCH" &>/dev/null || exit 1
    echo "Searching dependency updates..."
    mvn validate -Pversion |
        sed -rn '/\[INFO\] The following version/,/\[INFO\] +$/p' |
        sed -r -e 's/\[INFO\] +//' -e 's/.*available version.*/Latest:/' -e 's/.*are available.*/Updates:/' |
        head -n-1
    popd &>/dev/null || exit 1
}
