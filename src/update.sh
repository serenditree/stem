#!/usr/bin/env bash
########################################################################################################################
# UPDATE
# Global update tasks.
########################################################################################################################
# shellcheck disable=SC2155

# Updates versions defined in env.sh
# $1: Name of the component to update.
# $2: Current version.
# $2: Latest version.
function sc_update_env() {
    local -r _component=$1
    local -r _current=$2
    local -r _latest=$3

    if [[ -n "$_ARG_YES" ]]; then
        sed -Ei \
           "s/(export _ST_VERSION_$(tr '[:lower:]' '[:upper:]' <<<"$_component")=)[0-9.]+/\1${_latest}/" \
           "${_ST_HOME_STEM}/src/env.sh" &&
           echo "Updated ${_component} to version ${_latest}"
        if [[ $_ARG_YES -gt 1 ]]; then
           echo -e "\nPushing updates..."
           git -C "$_ST_HOME_STEM" commit -m "$_component $_latest;" src/env.sh
           git -C "$_ST_HOME_STEM" push
        fi
    else
       [[ "$_current" != "$_latest" ]] && echo -n "$_BOLD"
       echo -e "current: ${_current}\nlatest: ${_latest}${_NORMAL}" | column -t
    fi
}

# Checks helm dependency updates.
# $1 Log file to store versions.
function sc_update_helm_check() {
    local -r _log="$1"
    local -A _url2repo
    while IFS=";" read -r _repo _url; do
        _url2repo["$_url"]="$_repo"
    done <"${_ST_HOME_STEM}/rc/config/helm-setup"
    local -A _checked

    rm -f "$_log"
    while IFS=" " read -r _chart _repo_url _version; do
        local _repo_url="${_repo_url#*:}"
        _repo_url="${_repo_url%/}"
        local _repo_id=""
        local _repo_type=""

        if [[ -n "${_url2repo[${_repo_url}]}" ]]; then
            _repo_id="${_url2repo[${_repo_url}]}/${_chart#*:}"
            _repo_type="helm"
        elif [[ "${_repo_url%%:*}" == "oci" ]]; then
            _repo_id="${_repo_url#*//}/${_chart#*:}"
            _repo_type="oci"
        fi

        if [[ -n "$_repo_id" ]]; then
            local _repo_key="$(base64 <<<"$_repo_id")"
            if [[ -z "${_checked[${_repo_key}]}" ]]; then
                # Get latest version
                if [[ $_repo_type == "helm" ]]; then
                    local _latest="$(helm search repo "$_repo_id" --output json | jq -r '.[0] | .version')"
                else
                    local _latest="$(
                        skopeo list-tags "docker://${_repo_id}" |
                            jq -r '.Tags[]' |
                            sort -rV |
                            grep -Eiv 'rc|alpha|beta|latest' |
                            head -n1
                    )"
                fi
                # Output
                [[ "${_version#*:}" != "${_latest}" ]] && echo -n "$_BOLD"
                echo -e "\nartifact: ${_repo_id}\npath: ${_chart%%:*}\nversion: ${_version#*:}\nlatest: ${_latest}" |
                    column -Lt |
                    tee -a "$_log"
                echo -n "$_NORMAL"
                unset _repo_id
                _checked["${_repo_key}"]="true"
            fi
        else
            echo -e "\nRepo for ${_BOLD}${_chart#*:}${_NORMAL} (${_chart#*stem/charts/}) not configured!" >&2
        fi
    done < <(
        find "${_ST_HOME_STEM}/charts" -type d -name soil -prune -o -name Chart.yaml -exec bash \
            -c 'sed -En "s%[- ]+(name|repository|version): (.*)%$1:\2%p" $1' _ {} \; | # Prepends path to each match
            tr -d ' ' |
            xargs -n3
    )
}

# Applies helm dependency updates.
# $1 Log file with stored versions.
function sc_update_helm_apply() {
    local -r _log="$1"
    sc_heading 1 "Updating helm dependencies"
    sed -E "/${_ST_VERSION_FIXED_HELM:-st-none}/,/latest/d" "$_log" |
        grep -E '^(path|version|latest)' |
        awk '{print $2}' |
        xargs -n3 bash -c 'sed -i "s/$1/$2/" $0'
    git diff |
        grep -EB 3 "^\+\W+version: [0-9.v]+" |
        sed -E -e '/name: commons/,/version/d' -e '/repository/d' -e 's/^(\W+|.*:)//' |
        xargs -n3 |
        column -t

    sc_helm_pull
    sc_helm_push

    if [[ $_ARG_YES -gt 1 ]]; then
        sc_heading 1 "Pushing updates"
        git -C "$_ST_HOME_STEM" commit -am 'Dependencies update;'
        git -C "$_ST_HOME_STEM" push
    fi
    [[ -n "$_ST_VERSION_FIXED_HELM" ]] &&
        echo -e "\n${_BOLD}Warning:${_NORMAL} Skipped ${_ST_VERSION_FIXED_HELM};" | sed -E -e 's/\|/, /g' -e 's/\\//g'
}

# Checks helm dependency updates or applies them.
function sc_update_helm() {
    local -r _log=/tmp/sc-update-helm.log
    if [[ -z "$_ARG_YES" ]]; then
        helm repo update
        sc_update_helm_check "$_log"
    elif [[ -f "$_log" ]]; then
        sc_update_helm_apply "$_log"
    else
        echo -e "File $_log does not exits.\nPlease run 'sc update helm' first!"
        exit 1
    fi
}

# Checks versions of kustomize deployments.
function sc_update_kustomize() {
    while read -r _repo _current; do
        [[ -z "$_ARG_YES" ]] && sc_heading 2 "$_repo"
        local _latest=$(
            curl --silent "https://api.github.com/repos/${_repo//*.com\//}/releases/latest" | jq -r '.tag_name'
        )
        if [[ -z "$_ARG_YES" ]]; then
             [[ "$_current" != "$_latest" ]] && echo -n "$_BOLD"
            echo -e "current: ${_current}\nlatest: ${_latest}${_NORMAL}\n" | column -t
        else
            echo "Updating ${_repo} to ${_latest}."
            sed -Ei "s/(.*targetRevision: )${_current}/\1${_latest}/" "${_ST_HOME_STEM}/charts/tree/values.yaml"
        fi
    done < <(sed -En 's/.*(repoUrl|targetRevision): (.*)/\2/p' "${_ST_HOME_STEM}/charts/tree/values.yaml" | xargs -n 2)
    if [[ $_ARG_YES -gt 1 ]]; then
        git -C "$_ST_HOME_STEM" commit -am 'Dependencies update;'
        git -C "$_ST_HOME_STEM" push
    fi
}

# Updates base images or checks for upgrades.
function sc_update_image() {
    if [[ -n "$_ARG_YES" ]]; then
        env | grep "_ST_FROM_" | cut -d'=' -f2 | xargs podman pull
    else
        env | grep "_ST_FROM_" | grep -v ":latest" | sort | cut -d'=' -f2 | while read -r _image; do
            sc_heading 2 "$_image"
            # get current
            local _current=
            case $_image in
                *opensearch*)
                    _current=$(skopeo inspect containers-storage:$_image |
                        jq -r '.Labels."org.label-schema.version"')
                    ;;
                *postgres*)
                    _current=$(skopeo inspect containers-storage:$_image |
                        sed -En 's/.*PG_VERSION=([0-9.]+\.[0-9.]+).*/\1/p')
                    ;;
                *golang*)
                    _current=$(skopeo inspect containers-storage:$_image |
                        sed -En 's/.*GOLANG_VERSION=([0-9.]+).*/\1/p')
                    ;;
                *k6*)
                    _current=${_image##*:}
                    ;;
            esac
            # get latest
            local _latest=$(
                skopeo inspect docker://${_image%:*} |
                    jq -r '.RepoTags[]' |
                    sort -Vr |
                    sed -En '/^[[:digit:]]+\.[[:digit:]]+\.?[[:digit:]]*$/p' |
                    head -n1
            )
            # output
            [[ "$_current" != "$_latest" ]] && echo -n "$_BOLD"
            echo -e "current: ${_current}\nlatest: ${_latest}${_NORMAL}" | column -t
        done
    fi
}

# Kubernetes update.
function sc_update_kubernetes() {
    local -r _latest="$(exo compute sks versions --output-format text | sort -V | tail -n1)"
    sc_update_env "Kubernetes" "$_ST_VERSION_KUBERNETES" "$_latest"
}

# Updates maven dependencies or checks for updates.
function sc_update_maven() {
    pushd "$_ST_HOME_BRANCH" &>/dev/null || exit 1
    if [[ -n "$_ARG_YES" ]]; then
        echo "Updating dependencies..."
        mvn validate -Pupdate
    else
        if [[ -n "$_ARG_VERBOSE" ]]; then
            echo "Listing dependencies..."
            mvn dependency:list |
                sed -En 's/\[INFO\]\s{4}(\S+)\s.*/\1/p' |
                sort -u && echo
        fi
        echo "Searching dependency updates..."
        [[ -n "$_ARG_ALL" ]] && local -r _override='-Dversions.maven.plugin.rules='
        mvn validate -Pversion $_override |
            sed -rn '/\[INFO\] The following version/,/\[INFO\] +$/p' |
            sed -r -e 's/\[INFO\] +//' -e 's/.*available version.*/Latest:/' -e 's/.*are available.*/Updates:/' |
            head -n-1
    fi
    popd &>/dev/null || exit 1
}

# Tileserver update.
function sc_update_tileserver() {
    local -r _latest=$(yarn info tileserver-gl-light --json | jq -r '.data.version')
    sc_update_env "Tileserver" "$_ST_VERSION_TILESERVER" "$_latest"

    if [[ -n "$_ARG_YES" ]] && [[ "$_ST_VERSION_TILESERVER" != "$_latest" ]]; then
        export _ST_VERSION_TILESERVER="$_latest"
        sc_build root-map
    fi
}

# Updates node modules and syncs package.json with yarn.lock.
function sc_update_yarn() {
    pushd "$_ST_HOME_LEAF" &>/dev/null || exit 1
    yarn install
    if [[ -n "$_ARG_YES" ]]; then
        yarn upgrade-interactive
        ./dev/yarn.py
    else
        yarn outdated
    fi
    popd &>/dev/null || exit 1
}
