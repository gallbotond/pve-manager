#!/usr/bin/env bash

DRY_RUN=false

api_call() {

	local method="$1"
	local url="$2"

	if [[ "$DRY_RUN" == true ]]; then
		log "[DRY-RUN] $method $url"
		return
	fi

	curl -s -k -X "$method" \
		-H "$AUTH_HEADER" \
		"$url"
}

fetch_vms() {

	if [[ -n "${PVE_MANAGER_TEST_DATA:-}" ]]; then
		VM_DATA="$(cat "$PVE_MANAGER_TEST_DATA")"
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
