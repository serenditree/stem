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

# Spins up all or defined containers/services inside the local pod by executing the "run" action of the corresponding
# plot. If the  local pod does not yet exist, it is created.
# $*: Optional list of services.
function sc_pod_up() {
    local -r _plots="$(sc_args_to_pattern "$*")"

    if ! podman pod exists $_ST_POD; then
        sc_heading 1 "Creating pod"

        [[ -n "${_ARG_EXPOSE}${_ARG_INTEGRATION}" ]] &&
            local -r _expose='--publish 8085:3306 --publish 8086:27017 --publish 9092:9092' &&
            echo "Exposing ports..."

        podman pod create \
            --name $_ST_POD \
            --add-host root-user:127.0.0.1 \
            --add-host root-seed:127.0.0.1 \
            --add-host root-wind:127.0.0.1 \
            --add-host branch-poll:127.0.0.1 \
            --publish 8080-8084:8080-8084 $_expose
    fi

    sc_plots_do "${_plots}" up

    sc_heading 1 "Up and running"
    sc_pod_list
    if [[ -n "${_ARG_WATCH}${_ARG_INTEGRATION}" ]]; then
        sc_heading 1 "Waiting for readiness"
        echo -n 'Running health-checks...'
        until sc_pod_health >/dev/null; do echo -n '.'; done
        local -r _exit=$?
        echo 'done'
        sc_pod_health 'done'
        if [[ $_exit -ne 0 ]]; then
            # Cancel integration tests!
            sc_heading 2 "Error during startup!"
            exit 1
        fi
    fi
}

# Spins up a pod for integration testing.
# $1 Timestamp of the build to be tested.
# $2 The projects base-directory.
# $3 Flag that indicates if the pod should be shut down after each artifact.
# $4 Flag that indicates if the pod should be shut down after all artifacts were tested.
function sc_pod_integration_up() {
    local -r _build=/tmp/serenditree-build-${1//:/-}.log
    local -r _dir="$2"
    local _down_after_all=$3
    local _down_after_each=$4

    [[ "$_down_after_each" == "true" ]] &&
        [[ "$_down_after_all" == "false" ]] &&
        echo "[WARN] Invalid parameter combination..." &&
        _down_after_all=true

    if podman pod exists $_ST_POD; then
        echo "[INFO] Reusing existing pod..."
        local -r _pod_exists=true
    fi

    if [[ ! -f $_build ]]; then
        pushd $_dir &>/dev/null
        if [[ "$_down_after_each" == "false" ]] && [[ "$_down_after_all" == "true" ]]; then
            echo "[INFO] Saving build order..."
            mapfile -t _reactor \
                < <(mvn validate | sed -rn -e '/Reactor Build Order/,/-{2,}/p' | sed -rn 's/.+ (\S+) +\[.+/\1/p')
        fi
        if [[ -n "${_reactor[*]}" ]]; then
            echo "[INFO] First: ${_reactor[0]}"
            echo "[INFO] Last : ${_reactor[-1]}"
            echo "${_reactor[-1]}" >$_build
        else
            touch $_build
        fi
        popd &>/dev/null
        if [[ -z "$_pod_exists" ]]; then
            echo "[INFO] Starting pod..."
            sc_pod_up root-{user,seed,wind} branch
        fi
    fi
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

    if podman pod exists $_ST_POD; then
        podman container ls -a --format '{{.Names}} {{.Image}}' |
            grep serenditree |
            grep -E "${_containers}" |
            cut -d' ' -f1 |
            xargs -I{} -P0 bash -c 'sc_pod_down_sub {}'

        if [ -z "$*" ]; then
            echo -n "Removing pod..."
            podman pod rm --force $_ST_POD >/dev/null && echo "${_BOLD}done${_NORMAL}"
        fi
    else
        echo "Nothing to shut down."
    fi
}

# Shuts down the pod for integration testing after failure or each/all artifacts.
# $1 Timestamp of the build to be tested.
# $2 The projects base-directory and artifact id separated by '::'.
# $3 Flag that indicates if the pod should be shut down after each artifact.
# $4 Flag that indicates if the pod should be shut down after all artifacts were tested.
function sc_pod_integration_down() {
    local -r _build=/tmp/serenditree-build-${1//:/-}.log
    local -r _dir="${2%::*}"
    local -r _artifact="${2#*::}"
    local _down_after_all=$3
    local _down_after_each=$4

    [[ "$_down_after_each" == "true" ]] &&
        [[ "$_down_after_all" == "false" ]] &&
        _down_after_all=true

    # Shut down after each or all!
    if [[ -f $_build ]]; then
        local -r _last_artifact="$(cat $_build)"
    fi
    if [[ "$_down_after_each" == "true" ]] ||
        [[ "$_last_artifact" == "$_artifact" ]]; then
        if [[ "$_down_after_all" == "true" ]]; then
            echo "[INFO] Shutting pod down..."
            sc_pod_down ""
        fi
        rm -f $_build
    fi

    # Shut down if tests failed!
    # shellcheck disable=SC2038
    if [[ "$_down_after_all" == "true" ]] &&
        ! find ${_dir}/target/failsafe-reports -name '*.txt' \
            -exec sed -rn 's/.*Failures: ([0-9]+), Errors: ([0-9]+).*/\1\2/p' {} ';' |
        xargs -I{} test "{}" == "00"; then
        echo "[INFO] Shutting pod down..."
        sc_pod_down ""
        rm -f $_build
    fi
}

# Executes deployment scripts within all or defined Java containers/services.
# $*: Optional list of services.
function sc_pod_deploy() {
    podman pod exists $_ST_POD ||
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
# $1: Argument 'done' activates the 'quick' display (see function body) when --watch is set during startup.
# Return codes:
# 0: All containers are healthy
# 1: One or more containers are unhealthy
function sc_pod_health() {
    local _exit=0
    # quick (probably outdated health status depending on interval)
    if [[ "${_ARG_COMMAND}${1}" != "up" ]] &&
        { [[ -n "${_ARG_WATCH}${_ARG_COMPOSE}" ]] || [[ "$1" == "done" ]]; }; then
        if [[ -n "${_ARG_COMPOSE}" ]]; then
            local -r _filter="label=io.podman.compose.project=serenditree"
        else
            local -r _filter="pod=serenditree"
        fi
        if [[ "${1}" != "done" ]] && [[ -n "${_ARG_WATCH}" ]]; then
            local -r _duration=$(date -d "@$(($(date +%s) - _ST_START))" "+%Mm %Ss")
            echo -e "Monitoring health... ${_duration}\n"
        fi
        podman ps --filter $_filter --format '{{.Names}} {{.Status}}' |
            sed -rn 's/^(\S+).*\((starting|unhealthy|healthy)\)$/\1 \2/p' |
            sort |
            column -t
    # latest (actively run health-checks)
    else
        if [[ -z "$_ARG_INTEGRATION" ]]; then
            local -r _containers=(root-{seed,user,wind,map} branch-{seed,user,poll} leaf)
        else
            local -r _containers=(root-{seed,user,wind} branch-{seed,user,poll})
        fi
        for _container in "${_containers[@]}"; do
            if podman healthcheck run $_container >/dev/null; then
                local _status=healthy
            else
                local _status=unhealthy
                _exit=1
            fi
            echo "$_container: $_status"
        done
    fi
    return $_exit
}
export -f sc_pod_health
