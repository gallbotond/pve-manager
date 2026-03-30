#!/usr/bin/env bash

check_dependencies() {
	if ! command -v dialog >/dev/null 2>&1; then
		echo "Error: 'dialog' is not installed."
		echo ""
		echo "Install on NixOS:"
		echo "  nix-shell -p dialog"
		echo ""
		echo "Install on Debian/Ubuntu:"
		echo "  sudo apt install dialog"
		exit 1
	fi

	if ! command -v jq >/dev/null 2>&1; then
		echo "Error: 'jq' is required but not installed."
		echo "Install it with:"
		echo "  sudo apt install jq"
		echo "  OR"
		echo "  nix-shell -p jq"
		exit 1
	fi
}

load_config() {
	CONFIG_FILE="$CONFIG_DIR/proxmox.env"

	if [[ ! -f "$CONFIG_FILE" ]]; then
		echo "Missing configuration file:"
		echo "   $CONFIG_FILE"
		echo ""
		echo "Create it from the example:"
		echo "   cp $CONFIG_DIR/proxmox.env.example $CONFIG_FILE"
		exit 1
	fi

	# shellcheck source=/dev/null
	source "$CONFIG_FILE"

	if [[ -z "${API_URL:-}" || -z "${TOKEN_ID:-}" || -z "${TOKEN_SECRET:-}" ]]; then
		echo "Missing required variables in proxmox.env"
		exit 1
	fi

	AUTH_HEADER="Authorization: PVEAPIToken=$TOKEN_ID=$TOKEN_SECRET"
}

build_menu_items() {
	MENU_ITEMS=()

	MAX_NAME=0
	MAX_STATUS=0
	MAX_TAGS=0
	MAX_NODE=0

	while IFS= read -r vmid; do
		name=$(jq -r ".data[] | select(.vmid==$vmid) | .name // \"(noname)\"" <<<"$VM_DATA")
		status=$(jq -r ".data[] | select(.vmid==$vmid) | .status" <<<"$VM_DATA")
		tags=$(jq -r ".data[] | select(.vmid==$vmid) | .tags // \"\"" <<<"$VM_DATA")
		node=$(jq -r ".data[] | select(.vmid==$vmid) | .node" <<<"$VM_DATA")

		((${#name} > MAX_NAME)) && MAX_NAME=${#name}
		((${#status} > MAX_STATUS)) && MAX_STATUS=${#status}
		((${#tags} > MAX_TAGS)) && MAX_TAGS=${#tags}
		((${#node} > MAX_NODE)) && MAX_NODE=${#node}
	done < <(jq -r '.data | sort_by((.name//"")|ascii_downcase)[] | .vmid' <<<"$VM_DATA")

	while IFS= read -r vmid; do
		name=$(jq -r ".data[] | select(.vmid==$vmid) | .name // \"(noname)\"" <<<"$VM_DATA")
		status=$(jq -r ".data[] | select(.vmid==$vmid) | .status" <<<"$VM_DATA")
		tags=$(jq -r ".data[] | select(.vmid==$vmid) | .tags // \"\"" <<<"$VM_DATA")
		node=$(jq -r ".data[] | select(.vmid==$vmid) | .node" <<<"$VM_DATA")
		template=$(jq -r ".data[] | select(.vmid==$vmid) | .template" <<<"$VM_DATA")

		if [[ "$template" == "1" ]]; then
			icon="[T] "
		else
			icon="[VM]"
		fi

		printf -v name_fmt "%-${MAX_NAME}s" "$name"
		printf -v node_fmt "%-${MAX_NODE}s" "$node"
		printf -v tags_fmt "%-${MAX_TAGS}s" "$tags"

		if [[ "$template" == "1" ]]; then
			STATUS_FMT="\Z7template\Zn"
		else
			case "$status" in
			running) STATUS_FMT="\Z2running \Zn" ;;
			stopped) STATUS_FMT="\Z1stopped \Zn" ;;
			*) STATUS_FMT="\Z3${status}\Zn" ;;
			esac
		fi

		label="${icon} ${name_fmt} | ${node_fmt} | ${STATUS_FMT} |  tags: ${tags_fmt}"

		MENU_ITEMS+=("$vmid" "$label" "off")
	done < <(jq -r '.data | sort_by((.name//"")|ascii_downcase)[] | .vmid' <<<"$VM_DATA")
}

get_dialog_size() {
	TERM_HEIGHT=$(tput lines)
	TERM_WIDTH=$(tput cols)

	DIALOG_HEIGHT=$((TERM_HEIGHT - 4))
	DIALOG_WIDTH=$((TERM_WIDTH - 4))

	((DIALOG_HEIGHT < 15)) && DIALOG_HEIGHT=15
	((DIALOG_WIDTH < 60)) && DIALOG_WIDTH=60

	AVAILABLE_ROWS=$((DIALOG_HEIGHT - 8))
	((AVAILABLE_ROWS < 5)) && AVAILABLE_ROWS=5

	NUM_VMS=$((${#MENU_ITEMS[@]} / 3))
	((AVAILABLE_ROWS > NUM_VMS)) && AVAILABLE_ROWS=$NUM_VMS
}

execute_operation() {
	local vmid="$1"
	local operation="$2"

	local node
	node=$(jq -r ".data[] | select(.vmid==$vmid) | .node" <<<"$VM_DATA")

	local response
	local curl_exit
	local result=""

	case "$operation" in
	start)
		response=$(curl -s -k -X POST -H "$AUTH_HEADER" \
			"$API_URL/nodes/$node/qemu/$vmid/status/start")
		curl_exit=$?
		;;
	shutdown)
		response=$(curl -s -k -X POST -H "$AUTH_HEADER" \
			"$API_URL/nodes/$node/qemu/$vmid/status/shutdown")
		curl_exit=$?
		;;
	stop)
		response=$(curl -s -k -X POST -H "$AUTH_HEADER" \
			"$API_URL/nodes/$node/qemu/$vmid/status/stop")
		curl_exit=$?
		;;
	restart)
		response=$(curl -s -k -X POST -H "$AUTH_HEADER" \
			"$API_URL/nodes/$node/qemu/$vmid/status/reset")
		curl_exit=$?
		;;
	suspend)
		response=$(curl -s -k -X POST -H "$AUTH_HEADER" \
			"$API_URL/nodes/$node/qemu/$vmid/status/suspend")
		curl_exit=$?
		;;
	hibernate)
		response=$(curl -s -k -X POST -H "$AUTH_HEADER" \
			"$API_URL/nodes/$node/qemu/$vmid/status/suspend" \
			-d "skiplock=1&todisk=1")
		curl_exit=$?
		;;
	delete)
		response=$(curl -s -k -X DELETE -H "$AUTH_HEADER" \
			"$API_URL/nodes/$node/qemu/$vmid?purge=1")
		curl_exit=$?
		;;
	esac

	if [[ $curl_exit -ne 0 ]]; then
		result="FAILED (curl exit $curl_exit)"
	else
		local upid
		upid=$(jq -r '.data // empty' <<<"$response" 2>/dev/null)
		if [[ -n "$upid" && "$upid" == UPID:* ]]; then
			local task_id
			task_id=$(echo "$upid" | cut -d':' -f6)
			result="OK (task: ${task_id:0:8}...)"
		else
			local api_message
			api_message=$(jq -r '.message // .errors // empty' <<<"$response" 2>/dev/null)
			if [[ -n "$api_message" ]]; then
				result="FAILED ($api_message)"
			elif [[ -z "$response" || "$response" == "null" ]]; then
				result="OK"
			else
				result="OK"
			fi
		fi
	fi

	echo "$vmid ($node): $result"
}

run_ui() {

	DIALOG_THEME="$THEME_DIR/.dialogrc"

	if [[ -f "$DIALOG_THEME" ]]; then
		export DIALOGRC="$DIALOG_THEME"
	fi

	check_dependencies
	load_config

	while true; do
		fetch_vms
		build_menu_items
		get_dialog_size

		SELECTED_VMS=$(dialog --colors --clear \
			--title " Proxmox Bulk VM Manager " \
			--checklist "Select VMs to operate on:" \
			"$DIALOG_HEIGHT" "$DIALOG_WIDTH" "$AVAILABLE_ROWS" \
			"${MENU_ITEMS[@]}" \
			3>&1 1>&2 2>&3)

		status=$?
		clear

		if [[ $status -ne 0 ]]; then
			exit 0
		fi

		SELECTED_VMIDS=$(echo "$SELECTED_VMS" | tr -d '"')

		if [[ -z "$SELECTED_VMIDS" ]]; then
			dialog --msgbox "No VMs selected." 10 40
			clear
			continue
		fi

		OPERATION=$(dialog --clear \
			--menu "Choose an operation:" \
			17 60 7 \
			"start" "Start VM" \
			"shutdown" "Shutdown (ACPI)" \
			"stop" "Hard stop" \
			"restart" "Restart VM" \
			"suspend" "Suspend to RAM" \
			"hibernate" "Suspend to disk" \
			"delete" "Delete VM (purge)" \
			"quit" "Exit" \
			3>&1 1>&2 2>&3)

		clear

		if [[ -z "$OPERATION" || "$OPERATION" == "quit" ]]; then
			exit 0
		fi

		RESULTS="Command: $OPERATION\n\n"
		RESULTS+="Tasks queued on Proxmox cluster.\n"
		RESULTS+="Monitor progress in Proxmox web UI.\n\n"

		for vmid in $SELECTED_VMIDS; do
			vmid=$(tr -d '"' <<<"$vmid")
			RESULTS+=$(execute_operation "$vmid" "$OPERATION")
			RESULTS+="\n"
		done

		dialog --msgbox "$RESULTS" 22 65
		clear
	done
}
