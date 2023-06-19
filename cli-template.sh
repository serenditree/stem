#!/usr/bin/env bash
########################################################################################################################
# SERENDITREE COMMANDLINE INTERFACE
########################################################################################################################

# shellcheck disable=SC2154
_ST_HELP_DETAIL="'sc <command> --help' for details about a certain command!"
_ST_HELP="Please type 'sc <help>' for a list of commands or $_ST_HELP_DETAIL"
# m4_ignore(
_ST_ARGBASH=true
echo -n "Building Serenditree CLI..."
argbash cli-template.sh --output cli.sh
sed -Ei \
    -e 's/"\$0"/" sc" \&\& echo/' \
    -e 's/\(no-\)//g' \
    -e 's/, --no-[^:]+//g' \
    -e 's/\\t%s\\n([^:]+): /\\t%-20s%s\\n\1:" "/g' \
    -e 's/ \(off by default\)//g' \
    -e 's/FATAL //g' \
    -e "s/, but got only [^.]+./.\n\n$_ST_HELP/" \
    -e 's/(.*)"You have passed.*/\1"ERROR: Unknown option: $2"/' \
    cli.sh
echo "Done"
#)
# ARG_POSITIONAL_SINGLE([command], [Command to execute. Please type sc <help> for a list of commands!], [])
# ARG_OPTIONAL_BOOLEAN([test], [T], [Sets the target stage to test. (default is dev)])
# ARG_OPTIONAL_BOOLEAN([prod], [P], [Sets the target stage to prod. (default is dev)])
# ARG_OPTIONAL_BOOLEAN([dryrun], [D], [Activates dryrun mode.])
# ARG_OPTIONAL_BOOLEAN([verbose], [v], [Verbose flag.])
# ARG_OPTIONAL_BOOLEAN([all], [a], [All...])
# ARG_OPTIONAL_BOOLEAN([assume-yes], [y], [Assumes yes on prompts.])
# ARG_OPTIONAL_BOOLEAN([expose], [E], [Exposes database ports on local pods.])
# ARG_OPTIONAL_BOOLEAN([open], [], [Open plots.])
# ARG_OPTIONAL_BOOLEAN([watch], [w], [Watch supported commands.])
# ARG_OPTIONAL_BOOLEAN([init], [], [Initialization flag.])
# ARG_OPTIONAL_BOOLEAN([setup], [], [Setup flag.])
# ARG_OPTIONAL_BOOLEAN([upgrade], [], [Upgrade flag.])
# ARG_OPTIONAL_BOOLEAN([reset], [], [Reset flag.])
# ARG_OPTIONAL_BOOLEAN([delete], [], [Deletion flag.])
# ARG_OPTIONAL_BOOLEAN([imperative], [], [Imperative flag.])
# ARG_OPTIONAL_SINGLE([data], [d], [Pass arbitrary data.])
# ARG_OPTIONAL_SINGLE([issuer], [], [Set let's encrypt issuer to prod or staging.], [prod])
# ARG_OPTIONAL_BOOLEAN([compose], [], [Run or build for podman-compose.])
# ARG_OPTIONAL_BOOLEAN([integration], [], [Run for integration testing.])
# ARG_OPTIONAL_BOOLEAN([kubernetes], [k], [Use vanilla kubernetes.])
# ARG_OPTIONAL_BOOLEAN([openshift], [o], [Use openshift.])
# ARG_OPTIONAL_BOOLEAN([local], [l], [Target local cluster.])
# ARG_OPTIONAL_BOOLEAN([dashboard], [], [Open dashboard.])
# ARG_OPTIONAL_BOOLEAN([help], [h], [Command help. Please type sc <help> for a list of commands!])
# ARG_LEFTOVERS([Other arguments passed to command.])
# ARGBASH_SET_INDENT([    ])
# ARG_POSITIONAL_DOUBLEDASH()
# ARG_DEFAULTS_POS()
# ARGBASH_GO
# [

# shellcheck disable=SC2046
cd "$(dirname $(realpath $0))"

########################################################################################################################
# ARGUMENTS
########################################################################################################################

export _ARG_COMMAND=$_arg_command
# shellcheck disable=SC2206
export _ARG_LEFTOVERS=(${_arg_leftovers[*]})
export _ARG_SUB_COMMAND=${_arg_leftovers[0]}

export _ARG_DRYRUN=${_arg_dryrun/off/}
export _ARG_VERBOSE=${_arg_verbose/off/}
export _ARG_TEST=${_arg_test/off/}
export _ARG_PROD=${_arg_prod/off/}
export _ARG_ALL=${_arg_all/off/}
export _ARG_ASSUME_YES=${_arg_assume_yes/off/}

export _ARG_EXPOSE=${_arg_expose/off/}
export _ARG_OPEN=${_arg_open/off/}
export _ARG_INIT=${_arg_init/off/}
export _ARG_SETUP=${_arg_setup/off/}
export _ARG_UPGRADE=${_arg_upgrade/off/}
export _ARG_RESET=${_arg_reset/off/}
export _ARG_DELETE=${_arg_delete/off/}
export _ARG_IMPERATIVE=${_arg_imperative/off/}
export _ARG_WATCH=${_arg_watch/off/}
export _ARG_ISSUER=$_arg_issuer
export _ARG_DATA=$_arg_data
export _ARG_COMPOSE=${_arg_compose/off/}
export _ARG_INTEGRATION=${_arg_integration/off/}
export _ARG_KUBERNETES=${_arg_kubernetes/off/}
export _ARG_OPENSHIFT=${_arg_openshift/off/}
export _ARG_LOCAL=${_arg_local/off/}
export _ARG_DASHBOARD=${_arg_dashboard/off/}
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
    printf '\t%-20s%s\n' "expose:" "Port-forward operational services. [--reset|--delete]"
    printf '\t%-20s%s\n' "git [--] <cmd>:" "Execute arbitrary git commands."
    printf '\t%-20s%s\n' "health|hc:" "Runs health-checks on services. [--watch]"
    printf '\t%-20s%s\n' "loc:" "Prints lines of code."
    printf '\t%-20s%s\n' "login <reg>:" "Login to configured registries."
    printf '\t%-20s%s\n' "logs|log [svc]:" "Prints logs of all or individual services on the local pod."
    printf '\t%-20s%s\n' "plots:" "Prints all available plots. [--open]"
    printf '\t%-20s%s\n' "ps:" "Lists locally running serenditree containers."
    printf '\t%-20s%s\n' "push [svc]:" "Push all or individual images."
    printf '\t%-20s%s\n' "registry:" "Inspect images in remote registries. [--verbose]"
    printf '\t%-20s%s\n' "release:" "Updates the parent git repository and pushes new commits."
    printf '\t%-20s%s\n' "reset:" "Removes all local images created by this cli."
    printf '\t%-20s%s\n' "status:" "Prints status information and checks prerequisites."
    printf '\t%-20s%s\n' "update [comp]:" "Update components."

    printf '\n\t%s\n' "${_BOLD}Cluster commands:${_NORMAL}"
    printf '\t%-20s%s\n' "up [comp]:" "Cluster start/setup. [--init|--setup|--upgrade] [--imperative] [--dashboard]"
    printf '\t%-20s%s\n\n' "down:" "Cluster stop/deletion. [--reset|--delete]"

    printf '\t%-20s%s\n' "clean:" "Deletes dispensable resources."
    printf '\t%-20s%s\n' "dashboard:" "Launches the clusters dashboard."
    printf '\t%-20s%s\n' "database|db <db>:" "Open database console. {user|maria|seed|mongo}"
    printf '\t%-20s%s\n' "deploy:" "Deploys new images."
    printf '\t%-20s%s\n' "login:" "Login to OpenShift and its internal registry."
    printf '\t%-20s%s\n' "logs <svc>:" "Prints logs of the given pod(s)."
    printf '\t%-20s%s\n' "patch <arg>:" "Applies patches to the current cluster."
    printf '\t%-20s%s\n' "registry [img]:" "Inspects the OpenShift image registry."
    printf '\t%-20s%s\n' "resources|rc:" "Lists project resources."
    printf '\t%-20s%s\n' "certificate|cert:" "Prints certificate information."
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
expose)
    if [[ -n "$_ARG_RESET" ]]; then
        _ARG_DELETE=on sc_cluster_expose "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})"
        unset _ARG_DELETE
    fi
    sc_cluster_expose "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})"
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
    sc_plots_inspect "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})"
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
status)
    sc_status
    ;;
update)
    if [[ -n "$_ARG_HELP" ]]; then
        sc_heading 2 "sc update <comp>"
        echo "Update components. Without specification, all components are updated or checked for latest versions."
        printf '\n\t%-20s%s\n' "helm" "Check for latest chart versions."
        printf '\n\t%-20s%s' "{image* | img}" "Update base images or check for upgrades. [--upgrade]"
        printf '\n\t%-20s%s\n' "{maven | mvn}" "Check for maven dependency updates."
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
        *)
            sc_heading 1 helm
            sc_setup_helm_update
            sc_heading 1 images
            sc_setup_image_update
            sc_heading 1 maven
            sc_setup_maven_update
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
            _help_message+="[--init|--setup|--upgrade] [--imperative]"
            sc_heading 2 "$_help_message"
            echo "Starts or installs all or defined components."
            printf '\n\t%-20s%s\n' "--init" "Initialize terraform and create assets for openshift-install."
            printf '\n\t%-20s%s\n' "--setup" "Setup of the cluster in the current context."
            printf '\n\t%-20s%s\n' "--upgrade" "Upgrades the cluster in the current context."
            printf '\t%-20s%s\n' "--imperative" "Use imperative scripts for cloud setup."
        else
            time sc_plots_do "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})" up
        fi
        ;;
    down)
        if [[ -n "$_ARG_HELP" ]]; then
            _help_message="sc cluster down"
            _help_message+="[--reset|--delete] [--imperative]"
            sc_heading 2 "$_help_message"
            echo "Stops, deletes or resets the cluster in context. "
            printf '\t%-20s%s\n' "--reset" "Resets the cluster in the current context."
            printf '\t%-20s%s\n' "--delete" "Deletes the cluster in the current context."
            printf '\t%-20s%s\n' "--imperative" "Use imperative scripts for cloud deletion."
        elif [[ -n "$_ARG_DELETE" ]]; then
            time sc_plots_do "terra-base" down
        else
            time sc_plots_do "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})" down
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
        sc_cluster_deploy
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
            printf '\t%-20s%s\n' "osm-data:" "Sets ST_DATA_URL to the value of --data and triggers osm-data download."
            printf '\t%-20s%s\n' " " "If --data is missing, the environment variable gets reset."
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
        time sc_cluster_resources
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

# ]
