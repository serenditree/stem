#!/usr/bin/env bash
########################################################################################################################
# CONTAINER/IMAGE
# Common routines for image and container manipulation.
########################################################################################################################

# Stops and removes the given container.
# $1: Container id or name.
function sc_container_rm() {
    local -r _container=$1
    echo "Removing container ${_container}..."
    podman container ls | grep -q $_container && podman container stop $_container
    podman container exists $_container && podman container rm $_container
}
export -f sc_container_rm

# Removes inherited labels.
# $1: Base image identifier for retrieving existing labels.
# $2: Reference to the temporary container for label removal.
function sc_label_rm() {
    local -r _from=$1
    local -r _container_ref=$2
    echo "Removing inherited labels..."
    buildah inspect $_from | jq -r '.OCIv1.config.Labels | to_entries[] | "\(.key)-"' |
        xargs -I{} buildah config --label {} $_container_ref
}
export -f sc_label_rm

# Removes a predefined set of inherited environment variables.
# $1: Reference to the temporary container for environment variable removal.
function sc_env_rm() {
    local -r _container_ref=$1
    echo "Removing inherited environment variables..."
    buildah config --env SUMMARY- $_container_ref
    buildah config --env DESCRIPTION- $_container_ref
    buildah config --env STI_SCRIPTS_URL- $_container_ref
    buildah config --env STI_SCRIPTS_PATH- $_container_ref
}
export -f sc_env_rm

# Retrieves the given environment variable from the given image.
# $1: Image identifier.
# $2: Environment variable of interest.
function sc_env_get() {
    local -r _image=$1
    local -r _env=$2
    podman inspect $_image | sed -En "s/.*${_env}=([^\"]+).*/\1/p"
}
export -f sc_env_get

# Builds all or defined images based on the build block of the corresponding plot.
# $*: Optional list of images to build. Images are selected by grep pattern matching.
function sc_build() {
    local -r _plots="$(sc_args_to_pattern "$*")"

    if [[ -z "$_ST_CONTEXT_TKN" ]] && [[ "$_ST_FROM" == "rhel" ]]; then
        sc_heading 1 "Checking base images..."
        sc_login redhat
        local -r _pulled=$(
            env | grep "_ST_FROM_" | cut -d'=' -f2 |
                xargs -I{} bash -c "podman image exists {} || podman pull {}" |
                wc -l
        )
        [[ $_pulled -eq 0 ]] && echo "All set!"
    fi

    sc_plots_do "${_plots}" build
}

# Unified, OCI formatted buildah image commit.
# $1: Image identifier.
# $2: Image tag.
# $3: Reference to the temporary container.
function sc_image_commit() {
    local -r _image=$1
    local -r _tag=$2
    local -r _container_ref=$3

    # buildah config --author "$(git config --get user.email)" $_container_ref

    buildah commit --format oci $_container_ref ${_image}:${_tag}

    buildah inspect $_container_ref | jq '.OCIv1.config'
    buildah rm $_container_ref
}
export -f sc_image_commit

# Unified, OCI formatted buildah image commit with additional labels and environment variables to set. Used for
# services by now.
# $1: Name of the service the image defines.
# $2: Image identifier.
# $3: Version of the service.
# $4: Image tag.
# $5: Ordinal for sorting and build/deployment order.
# $6: Reference to the temporary container.
function sc_image_config_commit() {
    local -r _service=$1
    local -r _image=$2
    local -r _version=$3
    local -r _tag=$4
    local -r _ordinal=$5
    local -r _container_ref=$6

    buildah config --label serenditree.io/service=$_service $_container_ref
    buildah config --label serenditree.io/version=$_version $_container_ref
    buildah config --label serenditree.io/ordinal=$_ordinal $_container_ref
    buildah config --label serenditree.io/stage=$_ST_STAGE $_container_ref

    buildah config --env SERENDITREE_SERVICE=$_service $_container_ref
    buildah config --env SERENDITREE_VERSION=$_version $_container_ref
    buildah config --env SERENDITREE_ORDINAL=$_ordinal $_container_ref
    buildah config --env SERENDITREE_STAGE=$_ST_STAGE $_container_ref

    sc_image_commit "$_image" "$_tag" "$_container_ref"
}
export -f sc_image_config_commit

# Maps target stages ($_ST_STAGE) to standard tag names.
# $1: Tag to translate/map.
function sc_translate_tag() {
    local _tag=$1

    case $_tag in
    dev)
        _tag=latest
        ;;
    test)
        _tag=candidate
        ;;
    prod)
        _tag=stable
        ;;
    esac

    echo "$_tag"
}
export -f sc_translate_tag

# Tags and pushes an image to $_ST_REGISTRY.
# $1: Image identifier.
# $2: Image tag.
# $3: Target stage.
function sc_push() {
    local -r _image=$1
    local -r _tag=$2
    local -r _new_tag=$(sc_translate_tag "$3")

    local -r _target="${_ST_REGISTRY}/${_image}:${_new_tag}"

    if [[ -z "$_ST_CONTEXT_TKN" ]]; then
        # Copy using skopeo in local context.
        echo "Copying to ${_target}..."
        if [[ -z "$_ST_CONTEXT_OPENSHIFT" ]]; then
            local -r _skopeo_args='--dest-tls-verify=false'
        fi
        skopeo copy $_skopeo_args \
            containers-storage:localhost/${_image}:${_tag} \
            docker://${_target}
    else
        # Tag and push using buildah in CI environment.
        echo "Tagging ${_image}:${_tag} > ${_target}..."
        buildah tag "${_image}:${_tag}" "$_target"

        echo "Pushing ${_target}..."
        if [[ -z "$_ST_CONTEXT_OPENSHIFT" ]]; then
            local -r _buildah_args='--tls-verify=false'
        fi
        buildah push --digestfile /tmp/digestfile $_buildah_args "$_target"
        echo -n "${_target}@$(</tmp/digestfile)" | tee "$_ST_BUILD_RESULTS_PATH"
    fi
}
export -f sc_push

# Tags and pushes all or selected images defined in plots to $_ST_REGISTRY.
# $1: Pattern to select images.
function sc_push_plots() {
    #${_ORDINAL} ${_SERVICE} ${_IMAGE} ${_TAG} $(realpath $0)
    sc_plots "$1" | while read -r -a _plot; do
        local _image=${_plot[2]}
        local _tag=${_plot[3]}
        if [[ -n "${_image/-/}" ]]; then
            sc_heading 1 "Pushing ${_image}:${_tag} (${_ST_STAGE})"
            [[ -z "$_ARG_DRYRUN" ]] && sc_push $_image $_tag $_ST_STAGE
        fi
    done
}
export -f sc_push_plots

# Inspect images in remote registries.
# $1: Pattern to select images.
function sc_registry_inspect() {
    # Serenditree images
    sc_plots "$1" |
       cut -d' ' -f3 |
       grep serenditree |
       xargs -I{} bash -c "sc_heading 1 {} && skopeo inspect ${_ARG_VERBOSE//on/--config} docker://quay.io/{} | jq"
    # Base images
    env | grep -E '^_ST_FROM' | grep -E "$1" | cut -d'=' -f2 | while read -r _image; do
        sc_heading 1 "$_image"
        skopeo inspect ${_ARG_VERBOSE//on/--config} docker://${_image} | jq 'del(.RepoTags)'
        [[ -n "${_ARG_VERBOSE}" ]] && sc_heading 2 Tags && skopeo inspect docker://${_image} |
            jq -r '.RepoTags[]' |
            cut -d'.' -f1,2 |
            cut -d'-' -f1 |
            sort -Vu |
            sed '/latest/,$d'
    done
}

# Upgrades images.
# $1: Package manager.
# $2: Container reference.
function sc_distro_sync() {
    local -r _pkg_mgr=$1
    local -r _container_ref=$2

    if [[ $_pkg_mgr =~ dnf ]]; then
        buildah run --user 0:0 $_container_ref -- $_pkg_mgr distro-sync --assumeyes --noplugins
    else
        buildah run --user 0:0 $_container_ref -- yum upgrade --assumeyes --noplugins
    fi
    buildah run --user 0:0 $_container_ref -- $_pkg_mgr clean all --noplugins
}
export -f sc_distro_sync
