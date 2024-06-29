#!/usr/bin/env bash
########################################################################################################################
# COMPOSE
# Routines for podman-compose.
########################################################################################################################
# shellcheck disable=SC2068
_SC_COMPOSE='--file rc/compose/compose.yml --project-name serenditree'

function sc_compose() {
    if [[ "$1" == "up" ]]; then
        shift
        sc_compose_up $@
    else
        podman-compose $_SC_COMPOSE $@
    fi
}

function sc_compose_up() {
    local _podman_args
    _podman_args=$(${_ST_HOME_STEM}/plots/branch/src/secrets.sh podman)
    podman-compose $_SC_COMPOSE --podman-run-args "$_podman_args" up --detach $@
}

function sc_compose_down() {
    podman-compose $_SC_COMPOSE down $@
}
