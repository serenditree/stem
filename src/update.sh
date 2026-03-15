#!/usr/bin/env bash
########################################################################################################################
# UPDATE
# Global update tasks.
########################################################################################################################

# Checks helm dependency updates.
# $1 Log file to store versions.
function sc_update_helm_check() {
    local -r _log="$1"
    local -A _url2repo
    while IFS=";" read -r _repo _url; do
        _url2repo["$_url"]="$_repo"
    done <"${_ST_HOME_STEM}/rc/plain/setup-helm"

    rm -f "$_log"
    while IFS=" " read -r _chart _repo_url _version; do
        local _repo_url="${_repo_url#*:}"
        local _repo_id="${_url2repo[${_repo_url%/}]}"
        if [[ -n "$_repo_id" ]]; then
            _repo_id+="/${_chart#*:}"
            # shellcheck disable=SC2155
            local _latest="$(helm search repo "$_repo_id" --output json | jq -r '.[0] | .version')"
            echo -e "\nartifact: ${_repo_id}\npath: ${_chart%%:*}\nversion: ${_version#*:}\nlatest: ${_latest}" |
                column -Lt |
                tee -a "$_log"
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
    echo "Upgrading helm dependencies..."
    sed -E "/${_ST_VERSION_FIXED_HELM:-st-none}/,/latest/d" "$_log" |
        grep -E '^(path|version|latest)' |
        awk '{print $2}' |
        xargs -n3 bash -c 'sed -i "s/$2/$3/" $0 $1' "${_ST_CONTEXT_HOME}/bootstrap.tf"
    git diff |
        grep -EB 3 "^\+\W+version: [0-9.v]+" |
        sed -E -e '/name: commons/,/version/d' -e '/repository/d' -e 's/^(\W+|.*:)//' |
        xargs -n3 |
        column -t
    [[ -n "$_ST_VERSION_FIXED_HELM" ]] &&
        echo -e "\n${_BOLD}Warning:${_NORMAL} Skipped ${_ST_VERSION_FIXED_HELM};" | sed -E 's/\|/, /g'
}

# Checks helm dependency updates or applies them.
function sc_update_helm() {
    local -r _log=/tmp/sc-helm-update.log
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

# Updates base images or checks for upgrades.
function sc_update_image() {
    if [[ -n "$_ARG_YES" ]]; then
        env | grep "_ST_FROM_" | cut -d'=' -f2 | xargs podman pull
    else
        env | grep "_ST_FROM_" | cut -d'=' -f2 | while read -r _image; do
            sc_heading 2 "$_image"
            skopeo inspect docker://${_image%:*} |
                jq -r '.RepoTags[]' |
                sort -Vr |
                sed -rn '/^[[:digit:]]+\.[[:digit:]]+\.?[[:digit:]]*$/p' |
                head -n10
        done
    fi
}

# Updates maven dependencies or checks for updates.
function sc_update_maven() {
    pushd "$_ST_HOME_BRANCH" &>/dev/null || exit 1
    if [[ -n "$_ARG_YES" ]]; then
        echo "Updating dependencies..."
        quarkus up
        mvn validate -Pupdate
    else
        echo "Searching dependency updates..."
        mvn validate -Pversion |
            sed -rn '/\[INFO\] The following version/,/\[INFO\] +$/p' |
            sed -r -e 's/\[INFO\] +//' -e 's/.*available version.*/Latest:/' -e 's/.*are available.*/Updates:/' |
            head -n-1
    fi
    popd &>/dev/null || exit 1
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
