#!/usr/bin/env bash
########################################################################################################################
# BASH COMPLETION
# Bash completion script template for the serenditree command-line interface (sc).
########################################################################################################################
# shellcheck disable=SC2207

function _sc_completion() {
    local -r _current="${COMP_WORDS[COMP_CWORD]}"
    local -r _previous="${COMP_WORDS[COMP_CWORD - 1]}"
    local -r _local="${_LOCAL}"
    local -r _cluster="${_CLUSTER}"
    local _services="${_SERVICES}"

    # Options are not yet context aware.
    case "$_current" in
    --*)
        local -r _long="${_LONG}"
        ;;
    -)
        local -r _short="${_SHORT}"
        ;;
    esac

    case "$_previous" in
    cluster)
        COMPREPLY=($(compgen -W "$_cluster $_long $_short" -- "$_current"))
        ;;
    up | down | build | deploy | logs | log | push)
        # Basic context awareness for services (cluster or not)
        if ! [[ "${COMP_WORDS[*]}" =~ cluster ]]; then
            _services="${_services//terra-*/}"
        fi
        COMPREPLY=($(compgen -W "$_services $_long $_short" -- "$_current"))
        ;;
    database | db)
        COMPREPLY=($(compgen -W "user maria seed mongo" -- "$_current"))
        ;;
    *)
        COMPREPLY=($(compgen -W "$_local cluster help $_long $_short" -- "$_current"))
        ;;
    esac
}

complete -F _sc_completion sc
