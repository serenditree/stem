echo 'Aggregated status: $(params.status)'

STATUS=succeeded
for _status in $@; do
    if [[ "${_status##*:}" != "Succeeded" ]]; then
      STATUS=failed
    fi
    _status=${_status/Succeeded/ :green_heart:}
    _status=${_status/Failed/ :broken_heart:}
    DETAILS="${DETAILS}\n- ${_status/None/ :x:}"
done
TEXT='Pipeline $(params.pipeline) for revision $(params.git-sha)'
TEXT=${TEXT//\"//}
DETAILS+='\n\nCommit: $(params.git-log)\nImage: $(params.image-sha)'
DETAILS=${DETAILS//\"//}

curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"*${TEXT} ${STATUS}*${DETAILS}\"}" "${WEBHOOK}"
