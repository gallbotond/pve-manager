#!/usr/bin/env bash

vm_node() {
	jq -r ".data[] | select(.vmid==$1) | .node" <<<"$VM_DATA"
}

vm_status() {
	jq -r ".data[] | select(.vmid==$1) | .status" <<<"$VM_DATA"
}

vm_action() {

	local action="$1"
	shift

	for vmid in "$@"; do

		node=$(vm_node "$vmid")

		log "$action VM $vmid on $node"

		local api_result=0

		case "$action" in

		start)
			api_call POST \
				"$API_URL/nodes/$node/qemu/$vmid/status/start"
			api_result=$?
			;;

		shutdown)
			api_call POST \
				"$API_URL/nodes/$node/qemu/$vmid/status/shutdown"
			api_result=$?
			;;

		stop)
			api_call POST \
				"$API_URL/nodes/$node/qemu/$vmid/status/stop"
			api_result=$?
			;;

		restart)
			api_call POST \
				"$API_URL/nodes/$node/qemu/$vmid/status/reset"
			api_result=$?
			;;

		suspend)
			api_call POST \
				"$API_URL/nodes/$node/qemu/$vmid/status/suspend"
			api_result=$?
			;;

		hibernate)
			api_call POST \
				"$API_URL/nodes/$node/qemu/$vmid/status/suspend" \
				-H "Content-Type: application/x-www-form-urlencoded" \
				-d "skiplock=1&todisk=1"
			api_result=$?
			;;

		delete)
			status=$(vm_status "$vmid")

			if [[ "$status" == "running" ]]; then
				error "VM $vmid is running. Stop it before deleting."
				exit 1
			fi

			if [[ "$DRY_RUN" != true ]]; then
				confirm "Delete VM $vmid?"
			fi

			api_call DELETE \
				"$API_URL/nodes/$node/qemu/$vmid?purge=1"
			api_result=$?
			;;

		esac

		if [[ $api_result -eq 0 ]]; then
			log "OK: $vmid $action succeeded"
		else
			error "FAILED: $vmid $action"
		fi
	done
}

list_vms() {

	local sort_key="${LIST_SORT:-}"

	if [[ -n "$sort_key" ]]; then
		VM_DATA=$(jq --arg sort_key "$sort_key" '
			(.data // .) as $arr
			| {data: ($arr | sort_by(
				if $sort_key == "id" then .vmid | tonumber
				elif $sort_key == "node" then .node // ""
				elif $sort_key == "status" then .status // ""
				elif $sort_key == "name" then .name // ""
				else .vmid | tonumber end
			))}
		' <<<"$VM_DATA")
	fi

	jq -r '(.data // .)[] | "\(.vmid)\t\(.node)\t\(.status // "unknown")\t\(.name // "(noname)")"' <<<"$VM_DATA"

}
