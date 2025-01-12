DURATION=$(($(date +%s) - $(params.start)))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

STATUS=$(echo $(params.status) | tr '[:upper:]' '[:lower:]')
TITLE="*Pipeline \`$(params.pipeline)\` for commit \`$(params.git-sha)\` ${STATUS} in ${MINUTES}m ${SECONDS}s:*"
for _status in $@; do
    _status=${_status/Succeeded/ :green_heart:}
    _status=${_status/Failed/ :broken_heart:}
    DETAILS="${DETAILS}\n- ${_status/None/ :x:}"
done
DETAILS="${DETAILS}\n\n$(params.image-sha)"

echo -e "${TITLE}\n${DETAILS}\n"

curl -X POST "${WEBHOOK}" \
    --header "Content-type: application/json" \
    --data "{\"text\":\"${TITLE}\n${DETAILS}\"}"
