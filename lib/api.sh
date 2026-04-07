#!/usr/bin/env bash

: "${DRY_RUN:=false}"

api_call() {

	local method="$1"
	local url="$2"

	if [[ "$DRY_RUN" == true ]]; then
		custom_log "DRY-RUN" "$method $url"
		return 0
	fi

	local response
	local curl_exit
	response=$(curl -s -k -X "$method" \
		-H "$AUTH_HEADER" \
		"$url")
	curl_exit=$?

	if [[ $curl_exit -ne 0 ]]; then
		warn "curl failed with exit code $curl_exit"
		return 1
	fi

	local api_error
	api_error=$(jq -r '. // empty | select(.success == 0) | .message' <<<"$response")

	if [[ -n "$api_error" ]]; then
		warn "API error: $api_error"
		return 1
	fi

	return 0
}

fetch_vms() {

	if [[ -n "${PVE_MANAGER_TEST_DATA:-}" ]]; then
		VM_DATA="$(cat "$PVE_MANAGER_TEST_DATA")"
		return
	fi

	if [[ "$DRY_RUN" == true ]]; then
		VM_DATA='{"data":[]}'
		return
	fi

	log "Fetching VM list..."

	VM_DATA=$(curl -s -k \
		-H "$AUTH_HEADER" \
		"$API_URL/cluster/resources?type=vm")

	if [[ -z "$VM_DATA" ]]; then
		error "Failed to retrieve VM list"
		exit 1
	fi
}
