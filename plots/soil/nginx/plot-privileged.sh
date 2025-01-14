#!/usr/bin/env bash

# Disables countme in fedora repositories.
function sc_plot_privileged() {
    trap 'sudo sed -Ei "s/^countme=0/countme=1/" /etc/yum.repos.d/*' EXIT
    sudo sed -Ei 's/^countme=1/countme=0/' /etc/yum.repos.d/*
}
