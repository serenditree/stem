########################################################################################################################
# UTILS
# Collection of utility functions.
########################################################################################################################

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
        $_function $*
        _exit=$?
    fi
    unset _proceed

    return $_exit
}
export -f sc_prompt

# Adds bash-completion script to /etc/bash_completion.d/.
function sc_completion() {
    if [[ -n "$_ARG_ALL" ]]; then
        sc_heading 1 kubectl
        command -v kubectl && kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl
        sc_heading 1 oc
        command -v oc && oc completion bash | sudo tee /etc/bash_completion.d/oc
        sc_heading 1 helm
        command -v helm && helm completion bash | sudo tee /etc/bash_completion.d/helm
        sc_heading 1 tkn
        command -v tkn && tkn completion bash | sudo tee /etc/bash_completion.d/tkn
    fi

    sc_heading 1 sc
    local -r _cli="${_ST_HOME_STEM}/cli.sh"
    local -r _cmd_pattern='s/[[:space:]]+([^[:space:]|]+).*:[[:space:]]+[^[:space:]]+.*/\1/p'
    local -r _local=$(
        $_cli help |
            sed -n '/Local commands/,/Cluster commands/p' |
            sed -En "$_cmd_pattern" |
            sort -u |
            xargs echo
    )
    local -r _cluster=$(
        $_cli help |
            sed '0,/Cluster commands/d' |
            sed -En "$_cmd_pattern" |
            sort -u |
            xargs echo
    )
    local -r _long="$($_cli help | sed -En 's/.*(--\w+).*/\1/p' | sort -u | xargs echo)"
    local -r _short="$($_cli help | sed -En 's/.*\s(-\w).*/\1/p' | sort -u | xargs echo)"
    local -r _services="$(sc_plots | cut -d' ' -f2 | sed -E 's/soil-(\S+)/\0\n\1/' | sort | xargs echo)"

    sed -e "s/{{LOCAL}}/${_local}/" \
        -e "s/{{CLUSTER}}/${_cluster}/" \
        -e "s/{{LONG}}/${_long}/" \
        -e "s/{{SHORT}}/${_short}/" \
        -e "s/{{SERVICES}}/${_services}/" \
        ${_ST_HOME_STEM}/src/completion.sh |
        sudo tee /etc/bash_completion.d/sc
}
export -f sc_completion
