#!/usr/bin/env bash
########################################################################################################################
# TEST
# Prepares and runs tests.
########################################################################################################################

function sc_test_generate_openapi() {
    local -r _volume_src=${_ST_HOME_STEM}/rc/test/generated
    local -r _volume_target=/k6-test

    for _api in user:8081 seed:8082 poll:8083; do
        print_log "Generating tests for ${_api}..."
        _service="${_api%:*}"
        _port="${_api#*:}"
        _dir="${_volume_src}/${_service}"
        rm -rf "$_dir"
        mkdir -p "$_dir"

        podman run \
            --rm \
            --network host \
            --volume "${_dir}:${_volume_target}:Z" \
            docker.io/openapitools/openapi-generator-cli generate \
                --input-spec http://localhost:${_port}/api/v1/${_service}/openapi?format=json \
                --generator-name k6 \
                --output "${_volume_target}"
    done
}

function sc_test_generate_har() {
    local -r _har="$1"
    local -r _volume_src="${_har}"
    local -r _volume_target=/converter/"${_har##*/}"
    local -r _js="${_ST_HOME_STEM}/rc/test/generated/har-$(date +%Y%m%d-%H%M%S).js"
    echo -n "Generating tests from ${_har}..."
    podman run \
        --rm \
        --volume "${_volume_src}:${_volume_target}:Z" \
        docker.io/grafana/har-to-k6:latest -- \
        "${_har##*/}" > "$_js" &&
        echo -e "\033[3D: $_js"

}

function sc_test_run() {
    local -r _env="--env BRANCH_USER=localhost:8081 --env BRANCH_SEED=localhost:8082 --env BRANCH_POLL=localhost:8083"
    if k6 &>/dev/null; then
        k6 run $_env "${_ST_HOME_STEM}/charts/test/resources/main.js"
    else
        podman run \
            --rm \
            --network host \
            --volume "${_ST_HOME_STEM}/charts/test/resources/:/home/k6/:Z" \
            localhost/serenditree/testing:latest \
            run $_env main.js
    fi
}

function sc_test() {
    local -r _command="$1"
    local -r _har="$2"

    case "$_command" in
    openapi|api)
        sc_test_generate_openapi
        ;;
    har)
        sc_test_generate_har "$_har"
        ;;
    *)
        sc_test_run
        ;;
    esac
}
