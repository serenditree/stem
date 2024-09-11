DURATION=$(($(date +%s) - $(params.start)))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

STATUS=$(echo $(params.status) | tr '[:upper:]' '[:lower:]')
TITLE="*Pipeline \`$(params.pipeline)\` for commit \`$(params.git-sha)\` ${STATUS}:*"
for _status in $@; do
    _status=${_status/Succeeded/ :green_heart:}
    _status=${_status/Failed/ :broken_heart:}
    DETAILS+="\n- ${_status/None/ :x:}"
done
DETAILS+="\n\n$(params.image-sha)\n\nDuration: ${MINUTES}m${SECONDS}s"

echo -e "${TITLE}\n${DETAILS}\n"

curl -X POST "${WEBHOOK}" \
    --header "Content-type: application/json" \
    --data "{\"text\":\"${TITLE}\n${DETAILS}\"}"
