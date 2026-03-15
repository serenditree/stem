#!/usr/bin/env bash
########################################################################################################################
# HELM
# Collection of helm helpers.
########################################################################################################################
# shellcheck disable=SC2155,SC2048

# Helm repo setup and initial dependencies update.
function sc_helm_setup() {
    sc_heading 1 "Setting up helm"
    if [[ -z "$_ARG_DRYRUN" ]]; then
        echo "Adding repos..."
        while IFS=";" read -r _repo _url; do
            echo -n "${_repo}..."
            if helm repo ls | grep -Eq "^${_repo}"; then
                sc_heading 2 "set"
            else
                helm repo add "$_repo" "$_url"
            fi
        done <"${_ST_HOME_STEM}/rc/config/helm-setup"
    fi
}

# Helm dependencies update.
function sc_helm_dependencies() {
    [[ -n "$_ARG_INIT" ]] && sc_helm_setup
    sc_heading 1 "Updating dependencies..."
    local -r _pattern="$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]:1})"
    local _refresh
    while read -r _chart; do
        if grep -Eq '^dependencies:' "$_chart" && grep -Eq "$_pattern" "$_chart"; then
            dirname "$_chart" | xargs helm dependency update $_refresh
            _refresh=--skip-refresh
        fi
    done < <(find "${_ST_HOME_STEM}/charts" -name Chart.yaml)
}

# Packages and pushes the named template library.
function sc_helm_push() {
    # commons
    pushd "${_ST_HOME_STEM}/charts/soil" >/dev/null || exit 1
    helm package .
    helm push "$(ls ./*.tgz)" oci://quay.io/serenditree/charts
    # exoscale-webhook
    pushd "$(mktemp --directory)" >/dev/null || exit 1
    git clone --single-branch --depth 1 https://github.com/exoscale/cert-manager-webhook-exoscale.git .
    pushd ./deploy/exoscale-webhook >/dev/null || exit 1
    helm package .
    helm push "$(ls ./*.tgz)" oci://quay.io/tanwald/charts
}

# Prepares helm values to set.
function sc_helm_values() {
    sc_terra_render |
        sed -E 's/value:$/value: known-after-apply/' |
        sed -En -e 's/.*(- name:|value:) (.*)/\2/p' |
        xargs -n2 echo '--set' |
        tr ' ' '='
}

# Renders templates locally.
function sc_helm_template() {
    local -r _pattern="$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]:1})"

    [[ -z "$_ARG_VERBOSE" ]] &&
        local -r _skip_crds='select(.kind != "CustomResourceDefinition")' &&
        echo -e "Skipping CRDs\n"

    [[ -f "$_ST_CONTEXT_PLAN" ]] ||
        { echo "Plan (${_ST_CONTEXT_PLAN##*/}) does not exist. Aborting..." && exit 1; }
    echo -n "Preparing values..."
    local -r _values=$(sc_helm_values)
    echo -e "done\n\n${_values}\n"

    while read -r _chart; do
        pushd "${_chart%/*}" >/dev/null || exit 1
        local _name="$(sed -En 's/^name: (.*)/\1/p' Chart.yaml)"
        if [[ $_name =~ $_pattern ]]; then
            sc_heading 1 "$_name"
            echo $_values | xargs helm template --namespace $_name $_name . | yq "$_skip_crds"
        fi
        popd >/dev/null || exit 1
    done < <(find "${_ST_HOME_STEM}/charts" -type d -name soil -prune -o -name Chart.yaml -print)
}

# Prints chart information.
function sc_helm_charts() {
    while read -r _chart; do
        local _name="$(sed -En 's/^name: (.*)/\1/p' "$_chart")"
        if [[ -n "$_ARG_VERBOSE" ]]; then
            sc_heading 1 "$_name"
            yq "$_chart"
        else
            # Service, version, path
            echo "$_name" "$(sed -En 's/^version: ([0-9.]+).*/\1/p' "$_chart")" "${_chart%/*}"
        fi
    done < <(find "${_ST_HOME_STEM}/charts" -name Chart.yaml)
}

# Entrypoint for helm commands.
# $1: Subcommand
function sc_helm() {
    case $1 in
    charts)
        if [[ -n "$_ARG_VERBOSE" ]]; then
            sc_helm_charts
        else
            sc_helm_charts | nl | column -tN ORDINAL,SERVICE,VERSION,PATH
        fi
        ;;
    push)
        sc_helm_push
        ;;
    setup)
        sc_helm_setup
        ;;
    template)
        sc_helm_template
        ;;
    update)
        sc_helm_dependencies
        ;;
    esac
}

