#!/usr/bin/env bash
########################################################################################################################
# CONFIG
# Global settings and definitions.
########################################################################################################################
# UTILITY
########################################################################################################################
_NORMAL=$(tput sgr0 2>/dev/null)
_BOLD=$(tput bold 2>/dev/null)
export _NORMAL _BOLD
########################################################################################################################
# STAGE
########################################################################################################################
_ST_STAGE="dev"
if [[ -n "$_ARG_TEST" ]]; then
    _ST_STAGE="test"
elif [[ -n "$_ARG_PROD" ]]; then
    _ST_STAGE="prod"
fi
export _ST_STAGE
########################################################################################################################
# PROJECT
########################################################################################################################
if [[ -z "$_ST_CONTEXT_TKN" ]]; then
    _ST_HOME=$(realpath $0 | sed 's/\/stem.*//')
    export _ST_HOME
    export _ST_HOME_STEM=${_ST_HOME}/stem
    export _ST_HOME_BRANCH=${_ST_HOME}/branch
    export _ST_HOME_LEAF=${_ST_HOME}/leaf
else
    export _ST_HOME_STEM=${_ST_HOME}/sc
    export _ST_HOME_BRANCH=${_ST_HOME}/src
    export _ST_HOME_LEAF=${_ST_HOME}/src
fi
########################################################################################################################
# CONFIG
########################################################################################################################
export _ST_ACCOUNT=${_ST_ACCOUNT:-serenditree}
export _ST_DOMAIN=${_ST_DOMAIN:-serenditree.io}
export _ST_GIT=${_ST_GIT:-git@github.com:serenditree/stem.git}
export _ST_GIT_SSH=${_ST_GIT_SSH:-${HOME}/.ssh/stem@serenditree.io}
export _ST_LOG_LEVEL=${_ST_LOG_LEVEL:-info}
export _ST_POD=${_ST_POD:-serenditree}
export _ST_ZONE=${_ST_ZONE:-at-vie-1}

export EXOSCALE_ACCOUNT=$_ST_ACCOUNT
########################################################################################################################
# VERSIONS
########################################################################################################################
if [[ -f /etc/fedora-release ]] && [[ -z "$_ST_CONTEXT_TKN" ]]; then
    _ST_VERSION_FEDORA=$(cut -d' ' -f3 /etc/fedora-release)
    export _ST_VERSION_FEDORA
fi
export _ST_VERSION_KUBERNETES=1.32.3
export _ST_VERSION_JAVA=21
export _ST_VERSION_NODE=23.x
export _ST_VERSION_TILESERVER=5.0.0
export _ST_VERSION_ANGULAR=19
export _ST_VERSION_OPENSEARCH=2
export _ST_VERSION_POSTGRESQL=17
export _ST_VERSION_KAFKA=3.7.1
export _ST_VERSION_KAFKA_SCALA=2.13

export _ST_VERSION_FIXED_HELM='ingress-nginx\/ingress-nginx' # repo\/chart
########################################################################################################################
# BUILD
########################################################################################################################
export _ST_CONTAINER_ROOT=/serenditree

export _ST_JAVA_JRE_HOME=/usr/lib/jvm/jre-${_ST_VERSION_JAVA}-openjdk
export _ST_JAVA_JDK_HOME=/usr/lib/jvm/java-${_ST_VERSION_JAVA}-openjdk
export _ST_JAVA_PACKAGE=java-${_ST_VERSION_JAVA}-openjdk-headless
export _ST_JAVA_PACKAGE_DEVEL=java-${_ST_VERSION_JAVA}-openjdk-devel

export _ST_DNF_OPTS="--assumeyes --noplugins --nodocs --setopt install_weak_deps=0"
export _ST_DNF_OPTS_HOST="--use-host-config --releasever $_ST_VERSION_FEDORA $_ST_DNF_OPTS"
########################################################################################################################
# BASE IMAGES
########################################################################################################################
export _ST_FROM_ROOT_SEED=docker.io/bitnami/opensearch:${_ST_VERSION_OPENSEARCH}
export _ST_FROM_ROOT_USER=docker.io/bitnami/postgresql:${_ST_VERSION_POSTGRESQL}
########################################################################################################################
# CONTEXT
########################################################################################################################
_kubernetes="serenditree-kubernetes"
_kubernetes_local="serenditree-kubernetes-local"
_openshift="serenditree-openshift"
_openshift_local="serenditree-openshift-local"

# shellcheck disable=SC2155,SC2011
if [[ -z "$_ST_CONTEXT_TKN" ]]; then
    export MINIKUBE_IN_STYLE=false

    if [[ -n "$_ARG_KUBERNETES" ]]; then
        if [[ -n "$_ARG_LOCAL" ]]; then
            export _ST_CONTEXT=$_kubernetes_local
        else
            export _ST_CONTEXT=$_kubernetes
        fi
    elif [[ -n "$_ARG_OPENSHIFT" ]]; then
        if [[ -n "$_ARG_LOCAL" ]]; then
            export _ST_CONTEXT=$_openshift_local
        else
            export _ST_CONTEXT=$_openshift
        fi
    else
        _ST_CONTEXT=$(kubectl config current-context)
        export _ST_CONTEXT
    fi
fi

export _ST_CONTEXTS=("$_kubernetes" "$_kubernetes_local" "$_openshift" "$_openshift_local")
export _ST_CONTEXTS_NOOP="noop/serenditree"
export _ST_REGISTRY=quay.io
if [[ "$_ST_CONTEXT" == "$_kubernetes" ]]; then
    export _ST_CONTEXT_IS_KUBERNETES=on
    export _ST_CONTEXT_IS_REMOTE=on
    export _ST_CONTEXT_KUBERNETES=$_kubernetes
elif [[ "$_ST_CONTEXT" == "$_kubernetes_local" ]]; then
    export _ST_CONTEXT_IS_KUBERNETES=on
    export _ST_CONTEXT_IS_LOCAL=on
    export _ST_CONTEXT_KUBERNETES_LOCAL=$_kubernetes_local
elif [[ "$_ST_CONTEXT" == "$_openshift" ]]; then
    export _ST_CONTEXT_IS_OPENSHIFT=on
    export _ST_CONTEXT_IS_REMOTE=on
    export _ST_CONTEXT_OPENSHIFT=$_openshift
    export _ST_REGISTRY=default-route-openshift-image-registry.apps.serenditree...
elif [[ "$_ST_CONTEXT" == "$_openshift_local" ]]; then
    export _ST_CONTEXT_IS_OPENSHIFT=on
    export _ST_CONTEXT_IS_LOCAL=on
    export _ST_CONTEXT_OPENSHIFT_LOCAL=$_openshift_local
    export _ST_REGISTRY=default-route-openshift-image-registry.apps-crc.testing
else
    [[ -z "${_ST_ARGBASH}${_ST_CONTEXT_TKN}" ]] &&
        ! [[ $_ARG_COMMAND =~ [1-4]|ctx|context ]] &&
        echo -e "${_BOLD}Warning:${_NORMAL} Serenditree context is not set\n" >&2
    export _ST_CONTEXT=
fi
if [[ -n "$_ST_CONTEXT_IS_KUBERNETES" ]]; then
    export _ST_CONTEXT_HOME="${_ST_HOME_STEM}/src/kubernetes"
else
    export _ST_CONTEXT_HOME="${_ST_HOME_STEM}/src/openshift"
fi
export _ST_CONTEXT_PLAN="${_ST_CONTEXT_HOME}/serenditree.tfplan"
