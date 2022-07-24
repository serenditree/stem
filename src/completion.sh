#!/usr/bin/env bash
########################################################################################################################
# BASH COMPLETION
# Bash completion script for the serenditree command-line interface (sc).
########################################################################################################################
# shellcheck disable=SC2207

function _sc_completion() {
    local -r _services='{{SERVICES}}'
    local -r _local='{{LOCAL}}'
    local -r _cluster='{{CLUSTER}}'
    local -r _current="${COMP_WORDS[COMP_CWORD]}"
    local -r _previous="${COMP_WORDS[COMP_CWORD - 1]}"

    # Options are not yet context aware.
    case "$_current" in
    --*)
        local -r _long='{{LONG}}'
        ;;
    -)
        local -r _short='{{SHORT}}'
        ;;
    esac

    case "$_previous" in
    cluster)
        COMPREPLY=($(compgen -W "$_cluster $_services $_long $_short" -- "$_current"))
        ;;
    database | db)
        COMPREPLY=($(compgen -W "user maria seed mongo" -- "$_current"))
        ;;
    *)
        COMPREPLY=($(compgen -W "$_local cluster help $_services $_long $_short" -- "$_current"))
        ;;
    esac
}

complete -F _sc_completion sc
