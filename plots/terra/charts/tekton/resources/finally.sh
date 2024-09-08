echo "Aggregated status $(params.PIPELINE_AGGREGATE_STATUS)"

TEXT="Pipeline $(params.PIPELINE_NAME) for revision $(params.PIPELINE_REVISION)"
STATUS=succeeded
for _status in $@; do
    if [[ "${_status##*:}" != "Succeeded" ]]; then
      STATUS=failed
    fi
    _status=${_status/Succeeded/ :green_heart:}
    _status=${_status/Failed/ :broken_heart:}
    DETAILS="${DETAILS}\n- ${_status/None/ :x:}"
done

curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"*${TEXT} ${STATUS}*${DETAILS}\"}" "${WEBHOOK}"
