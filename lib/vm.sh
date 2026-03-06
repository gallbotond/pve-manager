#!/usr/bin/env bash

vm_node() {
	jq -r ".data[] | select(.vmid==$1) | .node" <<<"$VM_DATA"
}

vm_action() {

	local action="$1"
	shift

	for vmid in "$@"; do

		node=$(vm_node "$vmid")

		log "$action VM $vmid on $node"

		case "$action" in

		shutdown)
			api_call POST \
				"$API_URL/nodes/$node/qemu/$vmid/status/shutdown"
			;;

		stop)
			api_call POST \
				"$API_URL/nodes/$node/qemu/$vmid/status/stop"
			;;

		suspend)
			api_call POST \
				"$API_URL/nodes/$node/qemu/$vmid/status/suspend"
			;;

		delete)
			confirm "Delete VM $vmid?"
			api_call DELETE \
				"$API_URL/nodes/$node/qemu/$vmid?purge=1"
			;;

		esac
	done
}

list_vms() {

	jq -r '
.data[]
| "\(.vmid)\t\(.name)\t\(.status)\t\(.node)"
' <<<"$VM_DATA"

}
