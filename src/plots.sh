#!/usr/bin/env bash
########################################################################################################################
# PLOT
# Finding, selecting and executing plots. A plot is a folder containing a file named 'plot.sh'.
########################################################################################################################

# Finds plots and prints their definitions/information.
# $1: Pattern for plot filtering.
function sc_plots() {
    local -r _pattern=$1
    # shellcheck disable=SC2044
    { for _plot in $(find . -type d -path '*/\.*' -prune -o -name 'plot.sh' -print); do
        pushd ${_plot%/*} >/dev/null
        bash ./plot.sh info
        popd >/dev/null
    done; } | grep -E "$_pattern" | sort
}

# Prints or opens available plots.
# $1: Pattern for plot filtering.
function sc_plots_inspect() {
    local -r _pattern=$1
    if [[ -n "$_ARG_OPEN" ]]; then
        sc_plots $_pattern |
            sed -En 's/.* (\/.*\.sh).*/\1/p' |
            uniq |
            xargs -I{} bash -c "echo 'Opening {}...' && idea {} >/dev/null"
    else
        cat <(echo 'ID SERVICE IMAGE TAG PATH') <(sc_plots $_pattern) | column -ts' '
    fi
}

# Executes the given action for the given plot.
# $1: Path (location) of the plot.
# $*: Arguments containing action and modifiers.
function sc_plot_do() {
    local _plot=$1
    shift

    pushd ${_plot%/*} >/dev/null
    _plot=${_plot##*/}
    _plot=${_plot//:/ }
    if [[ " $* " =~ " build " ]] && [[ -z "$_ST_CONTEXT_TKN" ]]; then
        buildah unshare bash $_plot "$*"
    else
        bash $_plot "$*"
    fi
    popd >/dev/null
}

# Finds plots and executes defined actions.
# $1: Pattern for plot filtering.
# $*: Arguments containing action and modifiers.
function sc_plots_do() {
    local -r _pattern=$1
    shift
    for _plot in $(sc_plots $_pattern | cut -d' ' -f5); do
        sc_plot_do $_plot "$*"
    done
}
