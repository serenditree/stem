#!/usr/bin/env bash

# Prepares node repository for the installation of a specific node version.
# $1 Current node plot.
function sc_plot_privileged() {
    if [[ "$1" == "plot-node.sh:base:0" ]]; then
        sc_heading 1 "Preparing node repository"
        if [[ ! -f /etc/yum.repos.d/nodesource-nodejs.repo ]]; then
            trap 'sudo rm -rf /etc/yum.repos.d/nodesource-nodejs.repo' EXIT
        else
            echo "${_BOLD}waring:${_NORMAL} custom nodejs repository already exists."
        fi
        curl -fsSL "https://rpm.nodesource.com/setup_${_ST_VERSION_NODE}" | sudo bash -
    fi
}
