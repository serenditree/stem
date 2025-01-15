#!/usr/bin/env bash
########################################################################################################################
# NGINX
########################################################################################################################
# shellcheck disable=SC2086
_SERVICE=soil-nginx
_ORDINAL=5

_IMAGE=serenditree/nginx
_TAG=latest

_EXPOSE=8080/tcp

if [[ " $* " =~ " info " ]] || [[ -n "$_ARG_DRYRUN" ]]; then
    echo "${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)"
fi
########################################################################################################################
# BUILD
########################################################################################################################
if [[ " $* " =~ " build " ]]; then
    sc_heading 1 "Building ${_IMAGE}:${_TAG}"
    _OS_NAME="linux"
    _OS_VERSION="$(uname -r)"
    _OS_ARCH="amd64"
    _DNF_PKGS="c-ares-devel cmake gcc-c++ git openssl-devel openssl-devel-engine pcre2-devel zlib-ng-compat-devel"
    ####################################################################################################################
    # STEP BUILDER
    ####################################################################################################################
    _BUILD_CONTAINER_REF=$(buildah from scratch)
    _BUILD_MOUNT_REF=$(buildah mount $_BUILD_CONTAINER_REF)

    sc_heading 2 "Installing build-dependencies..."
    dnf install --installroot ${_BUILD_MOUNT_REF:?} $_ST_DNF_OPTS_HOST $_DNF_PKGS

    sc_heading 2 "Building and installing nginx with modules..."
    buildah config --env NGINX_ROOT="$_ST_CONTAINER_ROOT" $_BUILD_CONTAINER_REF
    buildah add $_BUILD_CONTAINER_REF ./src/make.sh /
    buildah run $_BUILD_CONTAINER_REF -- /make.sh

    _NGINX_VERSION="$(${_BUILD_MOUNT_REF:?}${_ST_CONTAINER_ROOT}/sbin/nginx -v 2>&1 | cut -d'/' -f2)"
    sc_heading 2 "Built nginx ${_NGINX_VERSION}."
    ####################################################################################################################
    # STEP PACKAGE
    ####################################################################################################################
    _CONTAINER_REF=$(buildah from scratch)
    _MOUNT_REF=$(buildah mount $_CONTAINER_REF)

    sc_heading 2 "Installing envsubst..."
    dnf install --installroot ${_MOUNT_REF:?} $_ST_DNF_OPTS_HOST gettext-envsubst
    dnf clean all --installroot ${_MOUNT_REF:?} --noplugins

    sc_heading 2 "Adding build artifacts..."
    buildah config --workingdir $_ST_CONTAINER_ROOT $_CONTAINER_REF
    buildah add --chown 1001:0 $_CONTAINER_REF ${_BUILD_MOUNT_REF:?}${_ST_CONTAINER_ROOT}
    buildah add --chown 1001:0 $_CONTAINER_REF ${_BUILD_MOUNT_REF:?}/usr/lib64/libcares.so\* \
                                               ${_BUILD_MOUNT_REF:?}/usr/lib64/libcrypt.so\* \
                                               ${_BUILD_MOUNT_REF:?}/usr/lib64/libcrypto.so\* \
                                               ${_BUILD_MOUNT_REF:?}/usr/lib64/libpcre\* \
                                               ${_BUILD_MOUNT_REF:?}/usr/lib64/libssl.so\* \
                                               ${_BUILD_MOUNT_REF:?}/usr/lib64/libstdc++.so\* \
                                               ${_BUILD_MOUNT_REF:?}/usr/lib64/libz.so\* \
                                               /usr/lib64/
    sc_heading 2 "Adding config and run-script..."
    buildah add --chown 1001:0 --chmod 440 $_CONTAINER_REF ./rc/serenditree.conf
    buildah add --chown 1001:0 --chmod 550 $_CONTAINER_REF ./src/run.sh

    sc_heading 2 "Configuring linked libraries..."
    buildah run --user 0:0 $_CONTAINER_REF -- ldconfig -v

    sc_heading 2 "Configuring image..."
    buildah config \
        --os "$_OS_NAME" \
        --os-version "$_OS_VERSION" \
        --arch "$_OS_ARCH" \
        --env DESCRIPTION="NGINX with otel module" \
        --env SERENDITREE_CONTENT="${_ST_CONTAINER_ROOT}/html" \
        --env SERENDITREE_CONFIG="${_ST_CONTAINER_ROOT}/conf/nginx.conf" \
        --env SERENDITREE_BIN="${_ST_CONTAINER_ROOT}/sbin/nginx" \
        --env OTEL_ENABLED="on" \
        --env OTEL_HOST="localhost" \
        --env OTEL_PORT="4317" \
        --env OTEL_SERVICE="leaf" \
        --env OTEL_SPAN="leaf-server" \
        --env NGINX_VERSION="$_NGINX_VERSION" \
        --env OS_NAME="$_OS_NAME" \
        --env OS_VERSION="$_OS_VERSION" \
        --env OS_ARCH="$_OS_ARCH" \
        --port "$_EXPOSE" \
        --stop-signal "SIGQUIT" \
        --user 1001:0 \
        --cmd "./run.sh" \
        $_CONTAINER_REF

    buildah umount $_BUILD_CONTAINER_REF
    buildah rm $_BUILD_CONTAINER_REF
    buildah umount $_CONTAINER_REF
    sc_image_config_commit "$_SERVICE" "$_IMAGE" "$_VERSION" "$_TAG" "$_ORDINAL" "$_CONTAINER_REF"
fi
