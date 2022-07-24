#!/usr/bin/env bash
########################################################################################################################
# GIT
# Collection of git shortcuts.
########################################################################################################################

# Executes the given command in root and all submodules.
# $*: Git command.
function sc_git() {
    cd $_ST_HOME
    sc_heading 1 "root"
    git "$*"
    git submodule foreach --recursive "sc_heading 1 \$name && git $*"
}
export -f sc_git

# Updates the submodules in root to point to HEAD and pushes root.
function sc_git_release() {
    cd $_ST_HOME
    git submodule update --recursive --remote
    git submodule foreach --recursive \
        'git checkout $(git config -f $toplevel/.gitmodules submodule.$name.branch || echo dev)'
    git commit -am 'Release;'
    git push
}
export -f sc_git_release
