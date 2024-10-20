#!/usr/bin/env bash
########################################################################################################################
# SERENDITREE COMMANDLINE INTERFACE
########################################################################################################################
# shellcheck disable=SC2154
_ST_HELP_DETAIL="'sc <command> --help' for details about a certain command!"
_ST_HELP="Please type 'sc <help>' for a list of commands or $_ST_HELP_DETAIL"
#
# ARG_POSITIONAL_SINGLE([command],[Command to execute. Please type sc <help> for a list of commands!],[])
# ARG_OPTIONAL_BOOLEAN([all],[a],[All...])
# ARG_OPTIONAL_BOOLEAN([compose],[],[Run or build for podman-compose.])
# ARG_OPTIONAL_BOOLEAN([dashboard],[],[Open dashboard.])
# ARG_OPTIONAL_BOOLEAN([delete],[],[Deletion flag.])
# ARG_OPTIONAL_BOOLEAN([dryrun],[D],[Activates dryrun mode.])
# ARG_OPTIONAL_BOOLEAN([expose],[E],[Exposes database ports on local pods.])
# ARG_OPTIONAL_BOOLEAN([help],[h],[Command help. Please type sc <help> for a list of commands!])
# ARG_OPTIONAL_BOOLEAN([init],[],[Initialization flag.])
# ARG_OPTIONAL_BOOLEAN([insert],[],[Inserts a new plot.])
# ARG_OPTIONAL_BOOLEAN([integration],[],[Run for integration testing.])
# ARG_OPTIONAL_BOOLEAN([kubernetes],[k],[Use vanilla kubernetes.])
# ARG_OPTIONAL_BOOLEAN([local],[l],[Target local cluster.])
# ARG_OPTIONAL_BOOLEAN([open],[],[Open plots.])
# ARG_OPTIONAL_BOOLEAN([openshift],[o],[Use openshift.])
# ARG_OPTIONAL_BOOLEAN([optional],[],[Include optional plots.])
# ARG_OPTIONAL_BOOLEAN([prod],[P],[Sets the target stage to prod. (default is dev)])
# ARG_OPTIONAL_BOOLEAN([reset],[],[Reset flag.])
# ARG_OPTIONAL_BOOLEAN([setup],[],[Setup flag.])
# ARG_OPTIONAL_BOOLEAN([test],[T],[Sets the target stage to test. (default is dev)])
# ARG_OPTIONAL_BOOLEAN([upgrade],[],[Upgrade flag.])
# ARG_OPTIONAL_BOOLEAN([verbose],[v],[Verbose flag.])
# ARG_OPTIONAL_BOOLEAN([watch],[w],[Watch supported commands.])
# ARG_OPTIONAL_BOOLEAN([yes],[y],[Assumes yes on prompts.])
# ARG_OPTIONAL_SINGLE([issuer],[],[Set let's encrypt issuer to prod or staging.],[prod])
# ARG_OPTIONAL_SINGLE([resume],[],[Resume plots from the given ordinal.],[0])
# ARG_LEFTOVERS([Other arguments passed to command.])
# ARG_DEFAULTS_POS([])
# ARG_RESTRICT_VALUES([no-any-options])
# ARG_POSITIONAL_DOUBLEDASH([])
# ARGBASH_SET_INDENT([    ])
# ARGBASH_GO()
# needed because of Argbash --> m4_ignore([
### START OF CODE GENERATED BY Argbash v2.10.0 one line above ###
# Argbash is a bash code generator used to get arguments parsing right.
# Argbash is FREE SOFTWARE, see https://argbash.io for more info


die()
{
    local _ret="${2:-1}"
    test "${_PRINT_HELP:-no}" = yes && print_help >&2
    echo "$1" >&2
    exit "${_ret}"
}


evaluate_strictness()
{
    [[ "$2" =~ ^--?[a-zA-Z] ]] && die "ERROR: Unknown option: $2"
}


begins_with_short_option()
{
    local first_option all_short_options='aDEhkloPTvwy'
    first_option="${1:0:1}"
    test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=()
_arg_command=
_arg_leftovers=()
# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_all="off"
_arg_compose="off"
_arg_dashboard="off"
_arg_delete="off"
_arg_dryrun="off"
_arg_expose="off"
_arg_help="off"
_arg_init="off"
_arg_insert="off"
_arg_integration="off"
_arg_kubernetes="off"
_arg_local="off"
_arg_open="off"
_arg_openshift="off"
_arg_optional="off"
_arg_prod="off"
_arg_reset="off"
_arg_setup="off"
_arg_test="off"
_arg_upgrade="off"
_arg_verbose="off"
_arg_watch="off"
_arg_yes="off"
_arg_issuer="prod"
_arg_resume="0"


print_help()
{
    printf 'Usage: %s [-a|--all] [--compose] [--dashboard] [--delete] [-D|--dryrun] [-E|--expose] [-h|--help] [--init] [--insert] [--integration] [-k|--kubernetes] [-l|--local] [--open] [-o|--openshift] [--optional] [-P|--prod] [--reset] [--setup] [-T|--test] [--upgrade] [-v|--verbose] [-w|--watch] [-y|--yes] [--issuer <arg>] [--resume <arg>] [--] <command> ... \n' " sc" && echo
    printf '\t%-20s%s\n' "<command>:" "Command to execute. Please type sc <help> for a list of commands!"
    printf '\t%-20s%s\n' "... :" "Other arguments passed to command."
    printf '\t%-20s%s\n' "-a, --all:" "All..."
    printf '\t%-20s%s\n' "--compose:" "Run or build for podman-compose."
    printf '\t%-20s%s\n' "--dashboard:" "Open dashboard."
    printf '\t%-20s%s\n' "--delete:" "Deletion flag."
    printf '\t%-20s%s\n' "-D, --dryrun:" "Activates dryrun mode."
    printf '\t%-20s%s\n' "-E, --expose:" "Exposes database ports on local pods."
    printf '\t%-20s%s\n' "-h, --help:" "Command help. Please type sc <help> for a list of commands!"
    printf '\t%-20s%s\n' "--init:" "Initialization flag."
    printf '\t%-20s%s\n' "--insert:" "Inserts a new plot."
    printf '\t%-20s%s\n' "--integration:" "Run for integration testing."
    printf '\t%-20s%s\n' "-k, --kubernetes:" "Use vanilla kubernetes."
    printf '\t%-20s%s\n' "-l, --local:" "Target local cluster."
    printf '\t%-20s%s\n' "--open:" "Open plots."
    printf '\t%-20s%s\n' "-o, --openshift:" "Use openshift."
    printf '\t%-20s%s\n' "--optional:" "Include optional plots."
    printf '\t%-20s%s\n' "-P, --prod:" "Sets the target stage to prod. (default is dev)"
    printf '\t%-20s%s\n' "--reset:" "Reset flag."
    printf '\t%-20s%s\n' "--setup:" "Setup flag."
    printf '\t%-20s%s\n' "-T, --test:" "Sets the target stage to test. (default is dev)"
    printf '\t%-20s%s\n' "--upgrade:" "Upgrade flag."
    printf '\t%-20s%s\n' "-v, --verbose:" "Verbose flag."
    printf '\t%-20s%s\n' "-w, --watch:" "Watch supported commands."
    printf '\t%-20s%s\n' "-y, --yes:" "Assumes yes on prompts."
    printf '\t%-20s%s\n' "--issuer:" "Set let's encrypt issuer to prod or staging. (default: 'prod')"
    printf '\t%-20s%s\n' "--resume:" "Resume plots from the given ordinal. (default: '0')"
}


parse_commandline()
{
    _positionals_count=0
    while test $# -gt 0
    do
        _key="$1"
        if test "$_key" = '--'
        then
            shift
            test $# -gt 0 || break
            _positionals+=("$@")
            _positionals_count=$((_positionals_count + $#))
            shift $(($# - 1))
            _last_positional="$1"
            break
        fi
        case "$_key" in
            -a|--no-all|--all)
                _arg_all="on"
                test "${1:0:5}" = "--no-" && _arg_all="off"
                ;;
            -a*)
                _arg_all="on"
                _next="${_key##-a}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    { begins_with_short_option "$_next" && shift && set -- "-a" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
                fi
                ;;
            --no-compose|--compose)
                _arg_compose="on"
                test "${1:0:5}" = "--no-" && _arg_compose="off"
                ;;
            --no-dashboard|--dashboard)
                _arg_dashboard="on"
                test "${1:0:5}" = "--no-" && _arg_dashboard="off"
                ;;
            --no-delete|--delete)
                _arg_delete="on"
                test "${1:0:5}" = "--no-" && _arg_delete="off"
                ;;
            -D|--no-dryrun|--dryrun)
                _arg_dryrun="on"
                test "${1:0:5}" = "--no-" && _arg_dryrun="off"
                ;;
            -D*)
                _arg_dryrun="on"
                _next="${_key##-D}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    { begins_with_short_option "$_next" && shift && set -- "-D" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
                fi
                ;;
            -E|--no-expose|--expose)
                _arg_expose="on"
                test "${1:0:5}" = "--no-" && _arg_expose="off"
                ;;
            -E*)
                _arg_expose="on"
                _next="${_key##-E}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    { begins_with_short_option "$_next" && shift && set -- "-E" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
                fi
                ;;
            -h|--no-help|--help)
                _arg_help="on"
                test "${1:0:5}" = "--no-" && _arg_help="off"
                ;;
            -h*)
                _arg_help="on"
                _next="${_key##-h}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    { begins_with_short_option "$_next" && shift && set -- "-h" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
                fi
                ;;
            --no-init|--init)
                _arg_init="on"
                test "${1:0:5}" = "--no-" && _arg_init="off"
                ;;
            --no-insert|--insert)
                _arg_insert="on"
                test "${1:0:5}" = "--no-" && _arg_insert="off"
                ;;
            --no-integration|--integration)
                _arg_integration="on"
                test "${1:0:5}" = "--no-" && _arg_integration="off"
                ;;
            -k|--no-kubernetes|--kubernetes)
                _arg_kubernetes="on"
                test "${1:0:5}" = "--no-" && _arg_kubernetes="off"
                ;;
            -k*)
                _arg_kubernetes="on"
                _next="${_key##-k}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    { begins_with_short_option "$_next" && shift && set -- "-k" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
                fi
                ;;
            -l|--no-local|--local)
                _arg_local="on"
                test "${1:0:5}" = "--no-" && _arg_local="off"
                ;;
            -l*)
                _arg_local="on"
                _next="${_key##-l}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    { begins_with_short_option "$_next" && shift && set -- "-l" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
                fi
                ;;
            --no-open|--open)
                _arg_open="on"
                test "${1:0:5}" = "--no-" && _arg_open="off"
                ;;
            -o|--no-openshift|--openshift)
                _arg_openshift="on"
                test "${1:0:5}" = "--no-" && _arg_openshift="off"
                ;;
            -o*)
                _arg_openshift="on"
                _next="${_key##-o}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    { begins_with_short_option "$_next" && shift && set -- "-o" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
                fi
                ;;
            --no-optional|--optional)
                _arg_optional="on"
                test "${1:0:5}" = "--no-" && _arg_optional="off"
                ;;
            -P|--no-prod|--prod)
                _arg_prod="on"
                test "${1:0:5}" = "--no-" && _arg_prod="off"
                ;;
            -P*)
                _arg_prod="on"
                _next="${_key##-P}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    { begins_with_short_option "$_next" && shift && set -- "-P" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
                fi
                ;;
            --no-reset|--reset)
                _arg_reset="on"
                test "${1:0:5}" = "--no-" && _arg_reset="off"
                ;;
            --no-setup|--setup)
                _arg_setup="on"
                test "${1:0:5}" = "--no-" && _arg_setup="off"
                ;;
            -T|--no-test|--test)
                _arg_test="on"
                test "${1:0:5}" = "--no-" && _arg_test="off"
                ;;
            -T*)
                _arg_test="on"
                _next="${_key##-T}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    { begins_with_short_option "$_next" && shift && set -- "-T" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
                fi
                ;;
            --no-upgrade|--upgrade)
                _arg_upgrade="on"
                test "${1:0:5}" = "--no-" && _arg_upgrade="off"
                ;;
            -v|--no-verbose|--verbose)
                _arg_verbose="on"
                test "${1:0:5}" = "--no-" && _arg_verbose="off"
                ;;
            -v*)
                _arg_verbose="on"
                _next="${_key##-v}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    { begins_with_short_option "$_next" && shift && set -- "-v" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
                fi
                ;;
            -w|--no-watch|--watch)
                _arg_watch="on"
                test "${1:0:5}" = "--no-" && _arg_watch="off"
                ;;
            -w*)
                _arg_watch="on"
                _next="${_key##-w}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    { begins_with_short_option "$_next" && shift && set -- "-w" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
                fi
                ;;
            -y|--no-yes|--yes)
                _arg_yes="on"
                test "${1:0:5}" = "--no-" && _arg_yes="off"
                ;;
            -y*)
                _arg_yes="on"
                _next="${_key##-y}"
                if test -n "$_next" -a "$_next" != "$_key"
                then
                    { begins_with_short_option "$_next" && shift && set -- "-y" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
                fi
                ;;
            --issuer)
                test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
                _arg_issuer="$2"
                shift
                evaluate_strictness "$_key" "$_arg_issuer"
                ;;
            --issuer=*)
                _arg_issuer="${_key##--issuer=}"
                evaluate_strictness "$_key" "$_arg_issuer"
                ;;
            --resume)
                test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
                _arg_resume="$2"
                shift
                evaluate_strictness "$_key" "$_arg_resume"
                ;;
            --resume=*)
                _arg_resume="${_key##--resume=}"
                evaluate_strictness "$_key" "$_arg_resume"
                ;;
            *)
                _last_positional="$1"
                _positionals+=("$_last_positional")
                _positionals_count=$((_positionals_count + 1))
                ;;
        esac
        shift
    done
}


handle_passed_args_count()
{
    local _required_args_string="'command'"
    test "${_positionals_count}" -ge 1 || _PRINT_HELP=yes die "ERROR: Not enough positional arguments - we require at least 1 (namely: $_required_args_string).

Please type 'sc <help>' for a list of commands or 'sc <command> --help' for details about a certain command!" 1
}


assign_positional_args()
{
    local _positional_name _shift_for=$1
    _positional_names="_arg_command "
    _our_args=$((${#_positionals[@]} - 1))
    for ((ii = 0; ii < _our_args; ii++))
    do
        _positional_names="$_positional_names _arg_leftovers[$((ii + 0))]"
    done

    shift "$_shift_for"
    for _positional_name in ${_positional_names}
    do
        test $# -gt 0 || break
        eval "$_positional_name=\${1}" || die "Error during argument parsing, possibly an Argbash bug." 1
        evaluate_strictness "$_positional_name" "${1##_arg}"
        shift
    done
}

parse_commandline "$@"
handle_passed_args_count
assign_positional_args 1 "${_positionals[@]}"

# OTHER STUFF GENERATED BY Argbash

### END OF CODE GENERATED BY Argbash (sortof) ### ])
# [ <-- needed because of Argbash
#
trap 'popd &>/dev/null || exit 1' EXIT
pushd "$(dirname "$(realpath $0)")" &>/dev/null || exit 1
########################################################################################################################
# ARGUMENTS
########################################################################################################################
export _ARG_COMMAND=$_arg_command
export _ARG_SUB_COMMAND=${_arg_leftovers[0]}
# shellcheck disable=SC2206
export _ARG_LEFTOVERS=(${_arg_leftovers[*]})

export _ARG_PROD=${_arg_prod/off/}
export _ARG_TEST=${_arg_test/off/}

export _ARG_ALL=${_arg_all/off/}
export _ARG_DRYRUN=${_arg_dryrun/off/}
export _ARG_VERBOSE=${_arg_verbose/off/}
export _ARG_YES=${_arg_yes/off/}

export _ARG_COMPOSE=${_arg_compose/off/}
export _ARG_KUBERNETES=${_arg_kubernetes/off/}
export _ARG_LOCAL=${_arg_local/off/}
export _ARG_OPENSHIFT=${_arg_openshift/off/}

export _ARG_DELETE=${_arg_delete/off/}
export _ARG_INIT=${_arg_init/off/}
export _ARG_OPTIONAL=${_arg_optional/off/}
export _ARG_RESET=${_arg_reset/off/}
export _ARG_RESUME=$_arg_resume
export _ARG_SETUP=${_arg_setup/off/}
export _ARG_UPGRADE=${_arg_upgrade/off/}

export _ARG_EXPOSE=${_arg_expose/off/}
export _ARG_INSERT=${_arg_insert/off/}
export _ARG_OPEN=${_arg_open/off/}
export _ARG_WATCH=${_arg_watch/off/}

export _ARG_DASHBOARD=${_arg_dashboard/off/}
export _ARG_ISSUER=$_arg_issuer

export _ARG_INTEGRATION=${_arg_integration/off/}

export _ARG_HELP=${_arg_help/off/}
########################################################################################################################
# IMPORT
########################################################################################################################
source ./src/env.sh

source ./src/cluster.sh
source ./src/compose.sh
source ./src/container.sh
source ./src/context.sh
source ./src/git.sh
source ./src/login.sh
source ./src/plots.sh
source ./src/pods.sh
source ./src/setup.sh
source ./src/status.sh
source ./src/utils.sh
########################################################################################################################
# HELP
########################################################################################################################
function sc_help() {
    sc_heading 2 "Serenditree CLI"
    print_help

    local _options
    printf '\n\t%s\n' "${_BOLD}Local commands:${_NORMAL}"
    _options='[--expose] [--watch] [--compose] [--integration]'
    printf '\t%-20s%s\n' "up [svc]:" "Starts a local development stack or a single container. $_options"
    _options='[--compose] [--integration] Stop cluster too: [--all]'
    printf '\t%-20s%s\n\n' "down [svc]:" "Stops local stack or single containers. $_options"

    printf '\t%-20s%s\n' "build [svc]:" "Builds all or individual images."
    printf '\t%-20s%s\n' "completion:" "Adds bash-completion script to /etc/bash_completion.d/. [--all]"
    printf '\t%-20s%s\n' "compose [--] <cmd>:" "Run podman-compose commands."
    printf '\t%-20s%s\n' "context|ctx [id]:" "Switch or display contexts."
    printf '\t%-20s%s\n' "database|db <db>:" "Open local database console. {user|maria|seed|mongo}"
    printf '\t%-20s%s\n' "deploy [svc]:" "Deploys all or individual services to the local stack."
    printf '\t%-20s%s\n' "env:" "Prints global environment variables based on context."
    printf '\t%-20s%s\n' "git [--] <cmd>:" "Execute arbitrary git commands."
    printf '\t%-20s%s\n' "health:" "Runs health-checks on services. [--watch]"
    printf '\t%-20s%s\n' "loc:" "Prints lines of code."
    printf '\t%-20s%s\n' "login <reg>:" "Login to configured registries."
    printf '\t%-20s%s\n' "logs|log [svc]:" "Prints logs of all or individual services on the local pod."
    printf '\t%-20s%s\n' "plots:" "Prints or inserts/deletes plots. [--open] [{--insert|--delete} ordinal name path]"
    printf '\t%-20s%s\n' "ps:" "Lists locally running serenditree containers."
    printf '\t%-20s%s\n' "push [svc]:" "Push all or individual images."
    printf '\t%-20s%s\n' "registry:" "Inspect images in remote registries. [--verbose]"
    printf '\t%-20s%s\n' "release:" "Updates the parent git repository and pushes new commits."
    printf '\t%-20s%s\n' "reset:" "Removes all local images created by this cli."
    printf '\t%-20s%s\n' "restore:" "Restores local databases from remote data."
    printf '\t%-20s%s\n' "status:" "Prints status information and checks prerequisites."
    printf '\t%-20s%s\n' "update [comp]:" "Update components."

    printf '\n\t%s\n' "${_BOLD}Cluster commands:${_NORMAL}"
    printf '\t%-20s%s\n' "up [comp]:" "Cluster start/setup. [--init|--setup|--upgrade] [--dashboard]"
    printf '\t%-20s%s\n\n' "down:" "Cluster stop/deletion. [--reset|--delete]"

    printf '\t%-20s%s\n' "certificate|cert:" "Prints certificate information."
    printf '\t%-20s%s\n' "clean:" "Deletes dispensable resources."
    printf '\t%-20s%s\n' "dashboard:" "Launches the clusters dashboard."
    printf '\t%-20s%s\n' "database|db <db>:" "Open database console. {user|maria|seed|mongo}"
    printf '\t%-20s%s\n' "deploy:" "Deploys new images."
    printf '\t%-20s%s\n' "expose:" "Port-forward operational services. [--reset|--delete]"
    printf '\t%-20s%s\n' "login:" "Login to OpenShift and its internal registry."
    printf '\t%-20s%s\n' "logs <svc>:" "Prints logs of the given pod(s)."
    printf '\t%-20s%s\n' "patch <arg>:" "Applies patches to the current cluster."
    printf '\t%-20s%s\n' "registry [img]:" "Inspects the OpenShift image registry."
    printf '\t%-20s%s\n' "resources|rc [csv]:" "Prints resource allocations. Optionally in CSV."
    printf '\t%-20s%s\n' "restore:" "Restore databases."
    printf '\t%-20s%s\n' "tekton|tkn [svc]:" "Triggers tekton runs for all or individual services."

    echo -e "\nPlease type $_ST_HELP_DETAIL"
}
########################################################################################################################
# MAIN
########################################################################################################################
case ${_ARG_COMMAND} in
########################################################################################################################
# LOCAL
########################################################################################################################
up)
    if [[ -n "$_ARG_INTEGRATION" ]]; then
        sc_pod_integration_up ${_ARG_LEFTOVERS[*]}
    elif [[ -n "$_ARG_COMPOSE" ]]; then
        time sc_compose_up ${_ARG_LEFTOVERS[*]}
    else
        time sc_pod_up ${_ARG_LEFTOVERS[*]}
    fi
    ;;
down)
    if [[ -n "$_ARG_INTEGRATION" ]]; then
        sc_pod_integration_down ${_ARG_LEFTOVERS[*]}
    elif [[ -n "$_ARG_COMPOSE" ]]; then
        time sc_compose_down ${_ARG_LEFTOVERS[*]}
    else
        time sc_pod_down ${_ARG_LEFTOVERS[*]}
    fi
    ;;
build)
    time sc_build ${_ARG_LEFTOVERS[*]}
    ;;
completion)
    sc_completion
    ;;
compose)
    sc_compose ${_ARG_LEFTOVERS[*]}
    ;;
context | ctx)
    sc_context ${_ARG_LEFTOVERS[*]}
    ;;
database | db)
    sc_login_db local ${_ARG_SUB_COMMAND}
    ;;
deploy)
    time sc_pod_deploy ${_ARG_LEFTOVERS[*]}
    ;;
env)
    sc_status_env
    ;;
git)
    sc_git ${_ARG_LEFTOVERS[*]}
    ;;
health)
    if [[ -n "$_ARG_WATCH" ]]; then
        _ST_START="$(date +%s)"
        export _ST_START
        watch -tn1 sc_pod_health
    else
        sc_pod_health
    fi
    ;;
loc)
    tokei -e .idea,.iml,.git,e2e,node_modules,target,lucene,javadoc,docs,dist -s files $_ST_HOME |
        sed -e '/-/d' -e 's/^ //' -e 's/=/-/g'
    ;;
login)
    if [[ -n "$_ARG_HELP" ]]; then
        sc_heading 2 "sc login <reg>"
        echo "Login to configured registries: redhat, quay, openshift, openshift/local"
    else
        sc_login "${_ARG_SUB_COMMAND}"
    fi
    ;;
logs | log)
    sc_pod_logs ${_ARG_LEFTOVERS[*]} || echo "Did you mean 'sc cluster logs'?"
    ;;
plots)
    if [[ -n "$_ARG_HELP" ]]; then
        sc_heading 2 "sc plots [ordinal name path]"
        echo "Prints or inserts/deletes plots. [--open] [--insert|--delete]"
        echo "Path needs to be absolute."
    elif [[ -n "$_ARG_INSERT" ]]; then
        sc_plots_insert "${_ARG_SUB_COMMAND}" "1" | sort -nk3
        sc_plots_template ${_ARG_LEFTOVERS[*]}
    elif [[ -n "$_ARG_DELETE" ]]; then
        sc_plots_insert "${_ARG_SUB_COMMAND}" "-1" | sort -nk3
    else
        sc_plots_inspect "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})"
    fi
    ;;
ps)
    sc_pod_list
    ;;
push)
    time sc_push_plots "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})"
    ;;
registry)
    time sc_registry_inspect "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})"
    ;;
release)
    sc_git_release
    ;;
reset)
    sc_pod_down
    podman image ls --format '{{.Repository}}:{{.Tag}}' | grep "localhost/serenditree" | xargs podman rmi
    ;;
restore)
    sc_pod_data_restore
    ;;
status)
    sc_status
    ;;
update)
    if [[ -n "$_ARG_HELP" ]]; then
        sc_heading 2 "sc update <comp>"
        echo "Update components. Without specification, all components are updated or checked for latest versions."
        printf '\n\t%-20s%s\n' "helm" "Check for latest chart versions."
        printf '\n\t%-20s%s' "{image* | img}" "Update base images or check for upgrades. [--yes]"
        printf '\n\t%-20s%s\n' "{maven | mvn}" "Updates maven dependencies or checks for updates. [--yes]"
        printf '\n\t%-20s%s\n' "yarn" "Updates node modules."
    else
        case ${_ARG_SUB_COMMAND} in
        helm)
            sc_setup_helm_update
            ;;
        image* | img)
            sc_setup_image_update
            ;;
        maven | mvn)
            sc_setup_maven_update
            ;;
        yarn)
            sc_setup_yarn_update
            ;;
        *)
            sc_heading 1 helm
            sc_setup_helm_update
            sc_heading 1 images
            sc_setup_image_update
            sc_heading 1 maven
            sc_setup_maven_update
            sc_heading 1 yarn
            sc_setup_yarn_update
        esac
    fi
    ;;
########################################################################################################################
# CLUSTER
########################################################################################################################
cluster)
    export _ST_CONTEXT_CLUSTER=on
    # shift leftovers array
    # shellcheck disable=SC2206
    export _ARG_LEFTOVERS=(${_ARG_LEFTOVERS[*]:1})
    case ${_ARG_SUB_COMMAND} in
    up)
        if [[ -n "$_ARG_HELP" ]]; then
            _help_message="sc cluster up [component] "
            _help_message+="[--init|--setup|--upgrade]"
            sc_heading 2 "$_help_message"
            echo "Starts or installs all or defined components."
            printf '\n\t%-20s%s\n' "--init" "Initialize terraform and create assets for openshift-install."
            printf '\n\t%-20s%s\n' "--setup" "Setup of the cluster in the current context."
            printf '\n\t%-20s%s\n' "--upgrade" "Upgrades the cluster in the current context."
        elif [[ -n "$_ST_CONTEXT"  ]]; then
            if [[ -n "$_ARG_SETUP" ]]; then
                time sc_plots_do "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})" up
            elif [[ -z "$_ARG_LEFTOVERS" ]]; then
                time sc_cluster_toggle start
            fi
        else
            echo "Context not set. Canceling..."
        fi
        ;;
    down)
        if [[ -n "$_ARG_HELP" ]]; then
            _help_message="sc cluster down [component]"
            _help_message+="[--reset|--delete]"
            sc_heading 2 "$_help_message"
            echo "Stops, deletes or resets the cluster in context. "
            printf '\t%-20s%s\n' "--reset" "Resets the cluster in the current context."
            printf '\t%-20s%s\n' "--delete" "Deletes the cluster in the current context."
        elif [[ -n "$_ST_CONTEXT"  ]]; then
            if [[ -n "$_ARG_DELETE" ]]; then
                time sc_plots_do "terra-base" down
            elif [[ -z "$_ARG_LEFTOVERS" ]]; then
                time sc_cluster_toggle stop
            else
                time sc_plots_do "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})" down
            fi
         else
            echo "Context not set. Canceling..."
        fi
        ;;
    clean)
        time sc_cluster_clean
        ;;
    dashboard)
        sc_cluster_dashboard
        ;;
    database | db)
        sc_login_db cluster ${_ARG_LEFTOVERS[*]}
        ;;
    deploy)
        sc_cluster_deploy "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})"
        ;;
    expose)
        if [[ -n "$_ARG_RESET" ]]; then
            _ARG_DELETE=on sc_cluster_expose "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})"
            unset _ARG_DELETE
        fi
        sc_cluster_expose "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})"
        ;;
    login)
        if [[ -n "$_ST_CONTEXT_OPENSHIFT" ]]; then
            sc_login openshift
        else
            sc_login openshift/local
        fi
        ;;
    logs | log)
        sc_cluster_logs ${_ARG_LEFTOVERS[*]}
        ;;
    patch)
        if [[ -n "$_ARG_HELP" ]]; then
            sc_heading 2 "sc cluster patch <arg>"
            echo "Applies patches to the current cluster."
            printf '\n\t%-20s%s\n' "nginx-ingress:" "Sets load balancing strategy to round-robin."
            printf '\t%-20s%s\n' "recreate:" "Patches deployment strategy for low performance environments."
            printf '\t%-20s%s\n' "argocd-cm:" "Patch ArgoCD config map to ignore resources."
        else
            sc_cluster_patch ${_ARG_LEFTOVERS[*]}
        fi
        ;;
    registry)
        time sc_cluster_registry ${_ARG_LEFTOVERS[*]}
        ;;
    resources | rc)
        time sc_cluster_resources ${_ARG_LEFTOVERS[*]}
        ;;
    restore)
        time sc_cluster_restore
        ;;
    backup)
        time sc_cluster_backup
        ;;
    cert*)
        time sc_cluster_certificate
        ;;
    tekton | tkn)
        time sc_plots_do "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})" tekton
        ;;
    *)
        sc_heading 2 "Unknown cluster command: ${_ARG_SUB_COMMAND}"
        print_help
        ;;
    esac
    ;;
help)
    sc_help
    ;;
*)
    if [[ -z "$_ST_ARGBASH" ]]; then
        sc_heading 2 "Unknown command: ${_ARG_COMMAND}"
        print_help
    fi
    ;;
esac
#
# ] <-- needed because of Argbash
