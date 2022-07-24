#!/usr/bin/env bash
########################################################################################################################
# COMPOSE
# Routines for podman-compose.
########################################################################################################################

_SC_COMPOSE='--file rc/compose/compose.yml --project-name serenditree'

function sc_compose() {
    podman-compose $_SC_COMPOSE "$@"
}

function sc_compose_up() {
    [[ -n "$_ARG_INIT" ]] && SERENDITREE_DATA_URL="$(pass serenditree/data.url)"
    export SERENDITREE_DATA_URL
    podman-compose $_SC_COMPOSE up --detach "$@"
}

function sc_compose_down() {
    podman-compose $_SC_COMPOSE down "$@"
}
