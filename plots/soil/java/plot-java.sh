#!/usr/bin/env bash
_FLAVOR=$1
_OFFSET=$2
########################################################################################################################
# JAVA
########################################################################################################################
_SERVICE=soil-java-${_FLAVOR}
_ORDINAL=$((_OFFSET + 10))

_IMAGE=serenditree/java-${_FLAVOR}
_VERSION=latest
_TAG=$_VERSION

_VOLUME_DST_REPO=${_ST_CONTAINER_ROOT}/.m2/repository

_JAVA_OPTIONS="-XshowSettings:vm -Djava.util.logging.manager=org.jboss.logmanager.LogManager"
_JAVA_RUN_VERSION=1.3.8
_JAVA_RUN_SCRIPT="https://repo1.maven.org/maven2/io/fabric8/run-java-sh"
_JAVA_RUN_SCRIPT="${_JAVA_RUN_SCRIPT}/${_JAVA_RUN_VERSION}/run-java-sh-${_JAVA_RUN_VERSION}-sh.sh"

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0):${_FLAVOR}:${_OFFSET}"
fi
########################################################################################################################
# BUILD
########################################################################################################################
if [[ " $* " =~ " build " ]]; then
    sc_heading 1 "Building java-${_FLAVOR}:${_TAG}"
    [[ -n "$_ARG_DRYRUN" ]] && exit 0
    ####################################################################################################################
    # BUILD BASE
    ####################################################################################################################
    if [[ "$_FLAVOR" == "base" ]]; then
        _DESCRIPTION="Java runtime (${_ST_JAVA_PACKAGE}) including curl."

        _CONTAINER_REF=$(buildah from scratch)
        _MOUNT_REF=$(buildah mount $_CONTAINER_REF)

        dnf install --installroot ${_MOUNT_REF:?} $_ST_DNF_OPTS_HOST $_ST_JAVA_PACKAGE curl ca-certificates
        dnf clean all --installroot ${_MOUNT_REF:?} --noplugins

        buildah run $_CONTAINER_REF -- mkdir $_ST_CONTAINER_ROOT
        buildah run $_CONTAINER_REF -- curl $_JAVA_RUN_SCRIPT -o ${_ST_CONTAINER_ROOT}/run.sh
        buildah run $_CONTAINER_REF -- chown -R 1000:0 $_ST_CONTAINER_ROOT
        buildah run $_CONTAINER_REF -- chmod u+x ${_ST_CONTAINER_ROOT}/run.sh
        buildah run $_CONTAINER_REF -- chmod -R g=u $_ST_CONTAINER_ROOT

        buildah config --label description="$_DESCRIPTION" $_CONTAINER_REF

        buildah config --env SERENDITREE_LOG_LEVEL=INFO $_CONTAINER_REF
        buildah config --env DESCRIPTION="$_DESCRIPTION" $_CONTAINER_REF
        buildah config --env JAVA_VERSION="$_ST_VERSION_JAVA" $_CONTAINER_REF
        buildah config --env JAVA_HOME="$_ST_JAVA_JRE_HOME" $_CONTAINER_REF
        buildah config --env JAVA_PACKAGE="$_ST_JAVA_PACKAGE" $_CONTAINER_REF
        buildah config --env JAVA_OPTIONS="$_JAVA_OPTIONS" $_CONTAINER_REF
        buildah config --env JAVA_RUN_SCRIPT="$_JAVA_RUN_SCRIPT" $_CONTAINER_REF
        buildah config --env JAVA_RUN_VERSION="$_JAVA_RUN_VERSION" $_CONTAINER_REF
        buildah config --env LANG="en_US.UTF-8" $_CONTAINER_REF
        buildah config --env LANGUAGE="en_US:en" $_CONTAINER_REF
    ####################################################################################################################
    # BUILD BUILDER
    ####################################################################################################################
    elif [[ "$_FLAVOR" == "builder" ]]; then
        _DESCRIPTION="Java development kit (${_ST_JAVA_PACKAGE}) including maven and curl."

        _CONTAINER_REF=$(buildah from serenditree/java-base)
        _MOUNT_REF=$(buildah mount $_CONTAINER_REF)

        dnf install --installroot ${_MOUNT_REF:?} $_ST_DNF_OPTS_HOST $_ST_JAVA_PACKAGE_DEVEL maven
        dnf clean all --installroot ${_MOUNT_REF:?} --noplugins

        buildah config --workingdir $_ST_CONTAINER_ROOT $_CONTAINER_REF

        buildah config --label description="$_DESCRIPTION" $_CONTAINER_REF

        buildah config --env SERENDITREE_LOG_LEVEL=DEBUG $_CONTAINER_REF
        buildah config --env DESCRIPTION="$_DESCRIPTION" $_CONTAINER_REF
        buildah config --env JAVA_HOME=$_ST_JAVA_JDK_HOME $_CONTAINER_REF
        buildah config --env M2_HOME="${_VOLUME_DST_REPO%/*}" $_CONTAINER_REF
        buildah config --env MAVEN_OPTS="-Dmaven.repo.local=${_VOLUME_DST_REPO}" $_CONTAINER_REF

        buildah run $_CONTAINER_REF -- mkdir src

        buildah add --chown 1000:0 $_CONTAINER_REF ./src
    fi

    sc_image_commit "$_IMAGE" "$_TAG" "$_CONTAINER_REF"
fi
