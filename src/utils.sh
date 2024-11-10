########################################################################################################################
# UTILS
# Collection of utility functions.
########################################################################################################################
# shellcheck disable=SC2155

# Prints the given message prominently to stdout.
# $1: Heading ID.
# $2: "n" or heading.
# $*: Heading.
function sc_heading() {
    local -r _heading_id=$1
    shift
    [[ "$1" == "n" ]] && shift && echo

    echo -n "${_BOLD}"
    [[ $_heading_id -eq 1 ]] && [[ -z "$_ST_CONTEXT_TKN" ]] && printf "%*s\n" $(tput cols) | tr " " "-"
    echo "$*"
    [[ $_heading_id -eq 1 ]] && [[ -z "$_ST_CONTEXT_TKN" ]] && printf "%*s\n" $(tput cols) | tr " " "-"
    echo -n "${_NORMAL}"
}
export -f sc_heading

# Grep pattern which selects everything if no additional terms (plots,...) are supplied.
# $*: Optional list of terms that will be compiled into an OR-pattern.
function sc_args_to_pattern() {
    local -r _args="$*"
    echo "st-all-or|${_args// /|}"
}
export -f sc_args_to_pattern

# Prompts the user before running a function. The prompt will be "$1 [y/N]: ".
# $1: Prompt message.
# $2: Function to execute.
# $*: Optional function parameters.
function sc_prompt() {
    echo -n $_BOLD
    read -rp "$1 [y/N]: " _proceed
    echo -n $_NORMAL
    local _exit=1
    if [[ "$_proceed" == "y" ]]; then
        local _function=$2
        shift 2
        # shellcheck disable=SC2068
        $_function $@
        _exit=$?
    fi
    unset _proceed

    return $_exit
}
export -f sc_prompt

# Adds bash-completion script to /etc/bash_completion.d/.
function sc_completion() {
    if [[ -n "$_ARG_ALL" ]]; then
        for _app in oc crc; do
            sc_heading 1 $_app
            command -v $_app && $_app completion bash | sudo tee "/etc/bash_completion.d/${_app}"
        done
    fi

    sc_heading 1 sc
    local -r _cli="${_ST_HOME_STEM}/cli.sh"
    local -r _cmd_pattern='s/[[:space:]]+([^[:space:]|]+).*:[[:space:]]+[^[:space:]]+.*/\1/p'

    export _LOCAL=$(
        $_cli help |
            sed -n '/Local commands/,/Cluster commands/p' |
            sed -En "$_cmd_pattern" |
            sort -u |
            xargs echo
    )
    export _CLUSTER=$(
        $_cli help |
            sed '0,/Cluster commands/d' |
            sed -En "$_cmd_pattern" |
            sort -u |
            xargs echo
    )
    export _LONG="$($_cli help | sed -En 's/.*(--\w+).*/\1/p' | sort -u | xargs echo)"
    export _SHORT="$($_cli help | sed -En 's/.*\s(-\w).*/\1/p' | sort -u | xargs echo)"
    export _SERVICES="$(
        _ARG_ALL=on sc_plots |
        cut -d' ' -f2 |
        sed -E 's/soil-(\S+)/\0\n\1/' |
        tr -d '*' |
        sort |
        xargs echo
    )"

    envsubst '$_LOCAL $_CLUSTER $_LONG $_SHORT $_SERVICES' <"${_ST_HOME_STEM}/rc/templates/completion.tpl" |
        sudo tee /etc/bash_completion.d/sc
}
export -f sc_completion
