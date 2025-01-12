#!/usr/bin/env bash
########################################################################################################################
# SETUP
# Global setup tasks.
########################################################################################################################

# Helm dependency init and repo setup.
function sc_setup_helm() {
    sc_heading 1 "Setting up helm"

    if [[ -z "$_ARG_DRYRUN" ]]; then
        echo "Adding repos..."
        while read -r _repo ; do
            echo -n "${_repo%%:*}..."
            if helm repo ls | grep -Eq "^${_repo%%:*}"; then
                sc_heading 2 "set"
            else
                helm repo add "${_repo%%:*}" "${_repo#*:}"
            fi
        done <"${_ST_RC}/setup-helm"
        echo "Updating dependencies..."
        local _refresh
        while read -r _chart; do
            if grep -q 'https://' $_chart; then
                dirname "$_chart" | xargs helm dependency update $_refresh
                _refresh=--skip-refresh
            fi
        done < <(find $_SC_HOME_STEM -name Chart.yaml)
    fi
}
export -f sc_setup_helm

# Helm dependency version update check or upgrade.
function sc_setup_helm_update() {
    local -r _log=/tmp/sc-helm-update.log
    if [[ -z "$_ARG_YES" ]]; then
        helm repo update && echo
        {
            while read -r _repo; do
                {
                    echo "id: $_repo"
                    # current version
                    find ./charts -name Chart.yaml \
                        -exec sh -c 'grep -hA2 "\- name: $2" $1 && echo path: $1' _ {} ${_repo#*/} \; |
                            sed -r 's/(^[- ]+)|(.\/)//' |
                            sort
                    # latest version
                    echo -n 'latest: '
                    helm search repo $_repo --output json | jq -r '.[0] | .version';
                } | column -t -s ':' -l 2 && echo
            done <"${_ST_RC}/setup-helm-update"
        } | tee "$_log"
        echo "details: helm search repo ID --output json"
    elif [[ -f "$_log" ]]; then
        echo "Upgrading helm dependencies..."
        sed -E "/${_ST_HELM_FIXED:-st-none}/,/latest/d" "$_log" |
            grep -E '^(path|version|latest)' |
            awk '{print $2}' |
            xargs -n3 bash -c 'sed -i "s/$1/$2/" $0'
        git diff |
            grep -EB 2 "version: [0-9.v]+" |
            sed -E -e '/repository/d' -e 's/^(\W+|.*:)//' |
            xargs -n3 |
            column -t
        [[ -n "$_ST_HELM_FIXED" ]] &&
            echo -e "\n${_BOLD}Warning:${_NORMAL} Skipped ${_ST_HELM_FIXED};" | sed -E 's/\|/, /g'
    else
        echo -e "File $_log does not exits.\nPlease run 'sc update helm' first!"
        exit 1
    fi
}

# Updates base images or checks for upgrades.
function sc_setup_image_update() {
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
function sc_setup_maven_update() {
    trap 'popd &>/dev/null || exit 1' EXIT
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
}

# Updates node modules and syncs package.json with yarn.lock.
function sc_setup_yarn_update() {
    trap 'popd &>/dev/null || exit 1' EXIT
    pushd "$_ST_HOME_LEAF" &>/dev/null || exit 1
    yarn install
    if [[ -n "$_ARG_YES" ]]; then
        yarn upgrade-interactive
        ./dev/yarn.py
    else
        yarn outdated
    fi
}
