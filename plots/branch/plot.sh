#!/usr/bin/env bash
# shellcheck disable=SC2068


if [[ -n "$_ST_CONTEXT_CLUSTER" ]]; then
    ./plot-branch.sh "-" "-" 1 $@
else
    ./plot-branch.sh user user 1 $@
    ./plot-branch.sh seed seed 2 $@
    ./plot-branch.sh poll user 3 $@
fi
