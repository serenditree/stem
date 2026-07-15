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
# ARG_OPTIONAL_BOOLEAN([all], [a], [All...])
# ARG_OPTIONAL_BOOLEAN([compose], [c], [Run or build for podman compose.])
# ARG_OPTIONAL_BOOLEAN([delete], [], [Deletion flag.])
# ARG_OPTIONAL_BOOLEAN([dryrun], [D], [Activates dryrun mode.])
# ARG_OPTIONAL_BOOLEAN([expose], [E], [Exposes database ports on local pods.])
# ARG_OPTIONAL_BOOLEAN([help], [h], [Command help. Please type sc <help> for a list of commands!])
# ARG_OPTIONAL_BOOLEAN([init], [], [Initialization flag.])
# ARG_OPTIONAL_BOOLEAN([insert], [], [Inserts a new plot.])
# ARG_OPTIONAL_BOOLEAN([integration], [], [Run for integration testing.])
# ARG_OPTIONAL_BOOLEAN([kubernetes], [k], [Use vanilla kubernetes.])
# ARG_OPTIONAL_BOOLEAN([local], [l], [Target local cluster.])
# ARG_OPTIONAL_BOOLEAN([notify], [n], [Enable desktop notifications.])
# ARG_OPTIONAL_BOOLEAN([open], [], [Open plots.])
# ARG_OPTIONAL_BOOLEAN([openshift], [o], [Use openshift.])
# ARG_OPTIONAL_BOOLEAN([prod], [P], [Sets the target stage to prod. (default is dev)])
# ARG_OPTIONAL_BOOLEAN([reset], [], [Reset flag.])
# ARG_OPTIONAL_BOOLEAN([restore], [], [Restore flag.])
# ARG_OPTIONAL_BOOLEAN([setup], [], [Setup flag.])
# ARG_OPTIONAL_BOOLEAN([test], [T], [Sets the target stage to test. (default is dev)])
# ARG_OPTIONAL_BOOLEAN([upgrade], [], [Upgrade flag.])
# ARG_OPTIONAL_BOOLEAN([wait], [w], [Wait for completion.])
# ARG_OPTIONAL_INCREMENTAL([verbose], [v], [Verbose flag.])
# ARG_OPTIONAL_INCREMENTAL([yes], [y], [Assumes yes on prompts.])
# ARG_OPTIONAL_BOOLEAN([xissuer], [x], [Set cert-issuer to prod when stage is not prod and vice versa.])
# ARG_OPTIONAL_SINGLE([scale], [s], [Machine auto-scaling.], [karpenter])
# ARG_OPTIONAL_SINGLE([resume], [], [Resume plots from the given plot.])
# ARG_LEFTOVERS([Other arguments passed to command.])
# ARG_DEFAULTS_POS()
# ARG_RESTRICT_VALUES([no-any-options])
# ARG_POSITIONAL_DOUBLEDASH()
# ARGBASH_SET_INDENT([    ])
# ARGBASH_GO
# [
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
export _ARG_VERBOSE=${_arg_verbose/0/}
export _ARG_YES=${_arg_yes/0/}
export _ARG_NOTIFY=${_arg_notify/off/}

export _ARG_COMPOSE=${_arg_compose/off/}
export _ARG_KUBERNETES=${_arg_kubernetes/off/}
export _ARG_LOCAL=${_arg_local/off/}
export _ARG_OPENSHIFT=${_arg_openshift/off/}

export _ARG_DELETE=${_arg_delete/off/}
export _ARG_INIT=${_arg_init/off/}
export _ARG_RESET=${_arg_reset/off/}
export _ARG_RESTORE=${_arg_restore/off/}
export _ARG_RESUME=$_arg_resume
export _ARG_SCALE=$_arg_scale
export _ARG_SETUP=${_arg_setup/off/}
export _ARG_UPGRADE=${_arg_upgrade/off/}

export _ARG_EXPOSE=${_arg_expose/off/}
export _ARG_INSERT=${_arg_insert/off/}
export _ARG_OPEN=${_arg_open/off/}

_ARG_WAIT=${_arg_wait/off/}
_ARG_WAIT=${_ARG_WAIT/on/true}
export _ARG_WAIT

export _ARG_XISSUER=${_arg_xissuer//off/}
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
source ./src/helm.sh
source ./src/login.sh
source ./src/plots.sh
source ./src/pods.sh
source ./src/status.sh
source ./src/update.sh
source ./src/utils.sh
source ./src/terra.sh
source ./src/test.sh
########################################################################################################################
# HELP
########################################################################################################################
function sc_help() {
    sc_heading 2 "Serenditree CLI"
    print_help

    local _options
    printf '\n\t%s\n' "${_BOLD}Local commands:${_NORMAL}"
    _options='[--expose] [--wait] [--compose] [--integration]'
    printf '\t%-20s%s\n' "up [svc]:" "Starts a local development stack or a single container. $_options"
    _options='[--compose] [--integration]'
    printf '\t%-20s%s\n\n' "down [svc]:" "Stops local stack or single containers. $_options"

    printf '\t%-20s%s\n' "build [svc]:" "Builds all or individual images."
    printf '\t%-20s%s\n' "backup:" "Backup local databases."
    printf '\t%-20s%s\n' "charts:" "Prints charts information."
    printf '\t%-20s%s\n' "completion:" "Adds bash-completion script to /etc/bash_completion.d/. [--all]"
    printf '\t%-20s%s\n' "compose [--] <cmd>:" "Run podman compose commands."
    printf '\t%-20s%s\n' "config:" "Prints cli and java config."
    printf '\t%-20s%s\n' "context [id]:" "Switch or display contexts."
    printf '\t%-20s%s\n' "database <db>:" "Open local database console. {user|seed}"
    printf '\t%-20s%s\n' "deploy [svc]:" "Deploys all or individual services to the local stack."
    printf '\t%-20s%s\n' "env:" "Prints global environment variables based on context."
    printf '\t%-20s%s\n' "expose:" "Port-forward operation-services. [--reset|--delete]"
    printf '\t%-20s%s\n' "git [--] <cmd>:" "Execute arbitrary git commands."
    printf '\t%-20s%s\n' "helm <cmd> [chart]:" "Push commons, update dependencies or render charts."
    printf '\t%-20s%s\n' "health:" "Runs health-checks on services. [--wait|--verbose]"
    printf '\t%-20s%s\n' "loc:" "Prints lines of code."
    printf '\t%-20s%s\n' "login <reg>:" "Login to configured registries."
    printf '\t%-20s%s\n' "logs|log [svc]:" "Prints logs of all or individual services on the local pod."
    printf '\t%-20s%s\n' "plots:" "Prints or inserts/deletes plots. [--open] [--insert|--delete]"
    printf '\t%-20s%s\n' "proxy:" "Proxy kubernetes services."
    printf '\t%-20s%s\n' "ps:" "Lists locally running serenditree containers."
    printf '\t%-20s%s\n' "push [svc]:" "Push all or individual images."
    printf '\t%-20s%s\n' "registry:" "Inspect images in remote registries. [--verbose]"
    printf '\t%-20s%s\n' "release:" "Updates the parent git repository and pushes new commits."
    printf '\t%-20s%s\n' "reset:" "Removes all local images created by this cli."
    printf '\t%-20s%s\n' "restore:" "Restores local databases from remote data."
    printf '\t%-20s%s\n' "rotate:" "Rotates JWK material locally."
    printf '\t%-20s%s\n' "status:" "Prints status information and checks prerequisites."
    printf '\t%-20s%s\n' "terra <cmd>:" "Run infra commands with all variables set."
    printf '\t%-20s%s\n' "test:" "Prepares and runs tests. [--delete][--verbose]"
    printf '\t%-20s%s\n' "update [comp]:" "Update components."

    printf '\n\t%s\n' "${_BOLD}Cluster commands:${_NORMAL}"
    printf '\t%-20s%s\n' "up:" "Cluster start/setup. [--init] [--setup] [--wait] [--scale]"
    printf '\t%-20s%s\n\n' "down:" "Cluster stop/deletion. [--reset|--delete] [--yes]"

    printf '\t%-20s%s\n' "backup:" "Setup backup cronjobs or run backups from cronjobs. [--setup]"
    printf '\t%-20s%s\n' "certificate:" "Prints certificate information."
    printf '\t%-20s%s\n' "clean:" "Deletes dispensable resources."
    printf '\t%-20s%s\n' "database <db>:" "Open database console. {user|seed}"
    printf '\t%-20s%s\n' "deploy:" "Deploys new images."
    printf '\t%-20s%s\n' "expose:" "Port-forward operation-services. [--reset|--delete]"
    printf '\t%-20s%s\n' "keys:" "List all keys in the cluster's vault."
    printf '\t%-20s%s\n' "login:" "Login to OpenShift and its internal registry."
    printf '\t%-20s%s\n' "logs <svc>:" "Prints logs of the given pod(s)."
    printf '\t%-20s%s\n' "proxy:" "Proxy kubernetes services."
    printf '\t%-20s%s\n' "registry [img]:" "Inspects the OpenShift image registry."
    printf '\t%-20s%s\n' "resources [csv]:" "Prints resource allocations. Optionally in CSV."
    printf '\t%-20s%s\n' "restore:" "Restore databases."
    printf '\t%-20s%s\n' "scale [type]:" "Adds an instance type to the karpenter nodepool."
    printf '\t%-20s%s\n' "status:" "Prints cluster status information."
    printf '\t%-20s%s\n' "tekton [svc]:" "Triggers tekton runs for all or individual services."
    printf '\t%-20s%s\n' "test:" "Run tests using k6-operator. [--delete]"
    printf '\t%-20s%s\n' "unseal:" "Unseal the cluster's vault"

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
    [[ "$_ARG_COMMAND" == "uc" ]] && export _ARG_COMPOSE=on
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
backup)
    sc_pod_data_backup
    ;;
charts)
    sc_helm charts
    ;;
completion)
    sc_completion
    ;;
compose)
    sc_compose ${_ARG_LEFTOVERS[*]}
    ;;
context)
    sc_context ${_ARG_LEFTOVERS[*]}
    ;;
config)
    sc_status_config
    ;;
database)
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
    if [[ "${_ARG_SUB_COMMAND}" == "backup" ]]; then
        sc_git push local --all
    else
        sc_git ${_ARG_LEFTOVERS[*]}
    fi
    ;;
helm)
    sc_helm ${_ARG_SUB_COMMAND}
    ;;
health)
    if [[ -n "$_ARG_WAIT" ]]; then
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
        sc_heading 2 "sc plots [ordinal [name path]]"
        echo "Prints or inserts/deletes plots. [--all] [--open] [--insert|--delete]"
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
proxy)
    sc_cluster_proxy
    ;;
ps)
    sc_pod_list silent
    ;;
push)
    time sc_push_plots "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})"
    ;;
registry)
    if [[ -n "$_ARG_HELP" ]]; then
        sc_heading 2 "sc registry {info|scan|age} [comp]"
        echo "Retrieves information from the registry."
    else
        export _ARG_LEFTOVERS=(${_ARG_LEFTOVERS[*]:1})
        case ${_ARG_SUB_COMMAND} in
            info)
                time sc_registry_inspect "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})"
                ;;
            scan)
                time sc_registry_scan "$(sc_args_to_pattern ${_ARG_LEFTOVERS[*]})"
                ;;
            age)
                time sc_registry_age
                ;;
        esac
    fi
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
rotate)
    sc_rotate_keys
    ;;
secrets)
    sc_terra_vault
    ;;
status)
    sc_status
    ;;
terra)
    sc_terra_run ${_ARG_LEFTOVERS[*]}
    ;;
test)
    sc_test ${_ARG_LEFTOVERS[*]}
    ;;
update)
    if [[ -n "$_ARG_HELP" ]]; then
        sc_heading 2 "sc update <comp> [--yes] [--yes]"
        echo "Update components. Without specification, all components are updated or checked for latest versions."
        printf '\n\t%-20s%s\n' "helm" "Update chart versions."
        printf '\n\t%-20s%s' "{image* | img}" "Update base images or check for upgrades."
        printf '\n\t%-20s%s\n' "kustomize" "Update additional kustomize deployments."
        printf '\n\t%-20s%s' "kubernetes" "Update Kubernetes."
        printf '\n\t%-20s%s' "{kafka}" "Update Kafka."
        printf '\n\t%-20s%s\n' "{maven | mvn | java}" "Update maven dependencies."
        printf '\n\t%-20s%s' "tile*" "Update Tileserver."
        printf '\n\t%-20s%s\n' "yarn" "Update node modules."
    else
        case ${_ARG_SUB_COMMAND} in
        helm)
            sc_update_helm
            ;;
        img | image*)
            sc_update_image "$(sc_args_to_pattern "${_ARG_LEFTOVERS[*]:1}")"
            ;;
        kustomize)
            sc_update_kustomize
            ;;
        kubernetes)
            sc_update_kubernetes
            ;;
        kafka)
            sc_update_kafka
            ;;
        maven | mvn | java)
            sc_update_maven
            ;;
        tile*)
            sc_update_tileserver
            ;;
        yarn)
            sc_update_yarn
            ;;
        "")
            sc_heading 1 helm
            sc_update_helm
            sc_heading 1 images
            sc_update_image
            sc_heading 1 kustomize
            sc_update_kustomize
            sc_heading 1 kubernetes
            sc_update_kubernetes
            sc_heading 1 kafka
            sc_update_kafka
            sc_heading 1 maven
            sc_update_maven
            sc_heading 1 tileserver
            sc_update_tileserver
            sc_heading 1 yarn
            sc_update_yarn
            ;;
        *)
            echo "Unknown component '${_ARG_SUB_COMMAND}'. Enter sc update --help for available components!"
            ;;
        esac
    fi
    ;;
[1-4])
    sc_context $_ARG_COMMAND
    ;;
########################################################################################################################
# CLUSTER
########################################################################################################################
cluster)
    if [[ -z "${_ST_CONTEXT}" ]]; then
        tput cuu1
        sc_heading 2 "Aborting..." >&2
        exit 1
    fi
    export _ST_CONTEXT_CLUSTER=on
    # shift leftovers array
    # shellcheck disable=SC2206
    export _ARG_LEFTOVERS=(${_ARG_LEFTOVERS[*]:1})
    case ${_ARG_SUB_COMMAND} in
    up)
        if [[ -n "$_ARG_HELP" ]]; then
            _help_message="sc cluster up"
            _help_message+="[--init|--setup|--upgrade]"
            sc_heading 2 "$_help_message"
            echo "Start or install the cluster of the current context."
            printf '\n\t%-20s%s\n' "--init" "Initialize OpenTofu and create assets for openshift-install."
            printf '\n\t%-20s%s\n' "--setup" "Setup the cluster of the current context."
            printf '\n\t%-20s%s\n' "--upgrade" "Upgrade the cluster of the current context."
        else
            if [[ -n "${_ARG_SETUP}${_ARG_INIT}" ]]; then
                time sc_terra_up
            else
                time sc_cluster_up
            fi
        fi
        ;;
    down)
        if [[ -n "$_ARG_HELP" ]]; then
            _help_message="sc cluster down"
            _help_message+="[--reset|--delete]"
            sc_heading 2 "$_help_message"
            echo "Stop, delete or reset the cluster of the current context. "
            printf '\t%-20s%s\n' "--reset" "Reset the cluster of the current context."
            printf '\t%-20s%s\n' "--delete" "Delete the cluster of the current context."
         else
            if [[ -n "$_ARG_DELETE" ]]; then
                sc_prompt "Delete cluster?" && time sc_terra_down
            else
                sc_prompt "Stop worker nodes?" && time sc_cluster_down
            fi
        fi
        ;;
    clean)
        time sc_cluster_clean
        ;;
    database)
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
    key*)
        sc_cluster_keys
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
    proxy)
        sc_cluster_proxy
        ;;
    registry)
        time sc_cluster_registry ${_ARG_LEFTOVERS[*]}
        ;;
    resources)
        time sc_cluster_resources ${_ARG_LEFTOVERS[*]}
        ;;
    restore)
        time sc_cluster_restore
        ;;
    scale)
        time sc_cluster_scale ${_ARG_LEFTOVERS[*]}
        ;;
    status)
        sc_status_cluster
        ;;
    backup)
        time sc_cluster_backup
        ;;
    certificate)
        time sc_cluster_certificate
        ;;
    tekton)
        time sc_cluster_tekton "${_ARG_LEFTOVERS[*]}"
        ;;
    test)
        sc_test_run_cluster
        ;;
    unseal)
        sc_cluster_unseal
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
