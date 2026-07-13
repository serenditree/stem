DURATION=$(($(date +%s) - $(params.start)))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

STATUS=$(tr '[:upper:]' '[:lower:]' <<<"$(params.status)")
COMMIT=$(sed 's/x-sc-failure/?/' <<<"$(params.git-sha)")
TITLE="*Pipeline \`$(params.pipeline)\` for commit \`${COMMIT}\` ${STATUS} in ${MINUTES}m ${SECONDS}s:*"
for _status in $@; do
    _status="${_status#*:} ${_status%:*}"
    _status=${_status/Succeeded/:green_heart:}
    _status=${_status/Failed/:broken_heart:}
    DETAILS="${DETAILS}\n${_status/None/:x:}"
done
DETAILS="${DETAILS}\n\n$(sed 's/x-sc-failure//' <<<"$(params.image-sha)")"

echo -e "${TITLE}\n${DETAILS}\n"

curl --request POST "${WEBHOOK}" \
    --header "Content-type: application/json" \
    --data "{\"text\":\"${TITLE}\n${DETAILS}\"}"
