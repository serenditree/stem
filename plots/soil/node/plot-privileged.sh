#!/usr/bin/env bash
# shellcheck disable=SC2064

# Prepares node repository for the installation of a specific node version.
# $1 Current node plot.
function sc_plot_privileged() {
    if [[ "$1" == "plot-node.sh:base:0" ]]; then
        sc_heading 1 "Preparing node repository"
        local -r _node_repo=/etc/yum.repos.d/nodesource-nodejs.repo
        local -r _trap_rm="sudo rm -f ${_node_repo}"
        local -r _trap_sed="sudo sed -Ei 's/^countme=0/countme=1/' /etc/yum.repos.d/*"
        if [[ -f $_node_repo ]]; then
            trap "${_trap_sed}" EXIT
            echo "${_BOLD}waring:${_NORMAL} custom nodejs repository already exists."
        else
            trap "${_trap_rm}; ${_trap_sed}" EXIT
        fi
        sudo sed -Ei 's/^countme=1/countme=0/' /etc/yum.repos.d/*
        curl -fsSL "https://rpm.nodesource.com/setup_${_ST_VERSION_NODE}" | sudo bash -
    fi
}
