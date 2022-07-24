#!/usr/bin/env bash
########################################################################################################################
# COMPOSE
# Routines for podman-compose.
########################################################################################################################

_SC_COMPOSE='--file rc/compose/compose.yml --project-name serenditree'

function sc_compose_up() {
    source ${_ST_HOME_STEM}/plots/branch/plot-branch-src.sh

    local _podman_args
    _podman_args=$(sc_branch_secrets podman)
    [[ -n "$_ARG_INIT" ]] && _podman_args+="--env SERENDITREE_DATA_URL=$(pass serenditree/data.url)"

    podman-compose $_SC_COMPOSE --podman-run-args "$_podman_args" up --detach "$@"
}

function sc_compose_down() {
    podman-compose $_SC_COMPOSE down "$@"
}
