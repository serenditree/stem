#!/usr/bin/env bash
########################################################################################################################
# POD
# Control of- and interaction with the local development pod.
########################################################################################################################

# Lists local pods with custom formatting.
function sc_pod_list() {
    local -r _columns="{{.Names}};{{.Image}};{{.Command}};{{.Ports}};{{.Status}}"
    cat \
        <(echo "$_columns" | tr -d '{}.' | tr '[:lower:]' '[:upper:]') \
        <(podman ps --filter label=serenditree.io/service --format "$_columns") | column -ts';'
}

# Stops and removes a single container.
# $1: Name of the container to remove.
function sc_pod_down_sub() {
    local -r _container=$1
    local -r _start=$(date +'%s')

    echo "Shutting down ${_container}..."
    podman container exists $_container && podman container stop $_container >/dev/null
    podman container rm $_container >/dev/null &&
        echo "Shut down ${_container}...${_BOLD}ok${_NORMAL} ($(($(date +'%s') - _start))s)"
}
export -f sc_pod_down_sub

# Stops and removes all or defined containers/services. In case of "all", the pod will be removed too.
# $*: Optional list of services.
function sc_pod_down() {
    local -r _containers=$(sc_args_to_pattern "$*")

    [[ -n "$_ARG_ALL" ]] && sc_heading 1 "Shutting pod down..."

    if podman pod exists serenditree; then
        podman container ls -a --format '{{.Names}} {{.Image}}' |
            grep serenditree |
            grep -E "${_containers}" |
            cut -d' ' -f1 |
            xargs -I{} -P0 bash -c 'sc_pod_down_sub {}'

        if [ -z "$*" ]; then
            echo -n "Removing pod..."
            podman pod rm --force serenditree >/dev/null && echo "${_BOLD}done${_NORMAL}"
        fi
    else
        echo "Nothing to shut down."
    fi
}

# Spins up all or defined containers/services inside the local pod by executing the "run" action of the corresponding
# plot. If the  local pod does not yet exist, it is created.
# $*: Optional list of services.
function sc_pod_up() {
    local -r _plots="$(sc_args_to_pattern "$*")"

    if ! podman pod exists serenditree; then
        sc_heading 1 "Creating pod"

        [[ -n "$_ARG_EXPOSE" ]] &&
            local -r _expose='--publish 8085:3306 --publish 8086:27017 --publish 9092:9092' &&
            echo "Exposing ports..."

        podman pod create \
            --name serenditree \
            --add-host root-user:127.0.0.1 \
            --add-host root-seed:127.0.0.1 \
            --add-host root-wind:127.0.0.1 \
            --add-host branch-poll:127.0.0.1 \
            --publish 8080-8084:8080-8084 $_expose
    fi

    sc_plots_do "${_plots}" up

    sc_heading 1 "Up and running"
    sc_pod_list
    if [[ -n "$_ARG_WATCH" ]]; then
        _ST_START="$(date +%s)"
        export _ST_START
        watch -tn1 sc_pod_health
    fi
}

# Executes deployment scripts within all or defined Java containers/services.
# $*: Optional list of services.
function sc_pod_deploy() {
    podman pod exists serenditree ||
        { echo "ERROR: Local pod does not exists. Did you mean sc cluster deploy...?" && exit 1; }
    sc_pod_up "$*"
}

# Prints and follows the logs of all or defined services.
# $*: Optional list of services.
function sc_pod_logs() {
    local -r _pods=$(sc_args_to_pattern "$*")

    # podman logs --names doesn't work with pods?
    local -r _id_to_name="$(podman ps --all --format '{{.ID}} {{.Names}} {{.Image}}' |
        grep serenditree |
        grep -E "$_pods" |
        sed -r "s/(.+) (.+) .*/^\1%${_BOLD}\2${_NORMAL}/" |
        xargs -I{} echo "-e s%{}%")"

    podman ps --all --format '{{.ID}} {{.Names}} {{.Image}}' |
        grep serenditree |
        grep -E "$_pods" |
        cut -d' ' -f1 |
        xargs podman logs --follow 2>&1 |
        sed -E ${_id_to_name//$'\n'/ }
}

# Runs health-checks on services.
function sc_pod_health() {
    if [[ -n "${_ARG_WATCH}${_ARG_COMPOSE}" ]]; then
        if [[ -n "${_ARG_COMPOSE}" ]]; then
            local -r _filter="label=io.podman.compose.project=serenditree"
        else
            local -r _filter="pod=serenditree"
        fi
        if [[ -n "${_ARG_WATCH}" ]]; then
            local -r _duration=$(date -d "@$(($(date +%s) - _ST_START))" "+%Mm %Ss")
            echo -e "Monitoring health... ${_duration}\n"
        fi
        podman ps --filter $_filter --format '{{.Names}} {{.Status}}' |
            sed -rn 's/^(\S+).*\((starting|unhealthy|healthy)\)$/\1 \2/p' |
            sort |
            column -t
    else
        for _branch in root-{seed,user,wind} branch-{seed,user,poll} leaf; do
            echo "$_branch: $(podman healthcheck run $_branch && echo healthy)"
        done
    fi
}
export -f sc_pod_health
