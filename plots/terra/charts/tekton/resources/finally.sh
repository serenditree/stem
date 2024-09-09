echo "Aggregated status: $(params.status)"

TEXT="Pipeline $(params.pipeline) for revision $(params.git-sha)"
STATUS=succeeded
for _status in $@; do
    if [[ "${_status##*:}" != "Succeeded" ]]; then
      STATUS=failed
    fi
    _status=${_status/Succeeded/ :green_heart:}
    _status=${_status/Failed/ :broken_heart:}
    DETAILS="${DETAILS}\n- ${_status/None/ :x:}"
done
DETAILS="${DETAILS}\n\nBuilt image $(params.image-sha)"

curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"*${TEXT} ${STATUS}*${DETAILS}\"}" "${WEBHOOK}"
