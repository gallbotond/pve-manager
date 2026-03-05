#!/usr/bin/env bash


#==============================================================
# Dark mode dialog configuration
#==============================================================
# Resolve absolute path even if script is symlinked
SCRIPT_PATH="$(readlink -f "$0")"
# SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

if [[ -f "$SCRIPT_DIR/.dialogrc" ]]; then
    export DIALOGRC="$SCRIPT_DIR/.dialogrc"
fi

echo "SCRIPT DIR: $(dirname "$0")"

#==============================================================
# Dependency checks
#==============================================================
if ! command -v dialog >/dev/null 2>&1; then
    echo "❌ Error: 'dialog' is not installed."
    echo ""
    echo "Install on NixOS:"
    echo "  nix-shell -p dialog"
    echo ""
    echo "Install on Debian/Ubuntu:"
    echo "  sudo apt install dialog"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "❌ Error: 'jq' is required but not installed."
    echo "Install it with: sudo apt install jq   OR   nix-shell -p jq"
    exit 1
fi


#==============================================================
# Load Proxmox token credentials
#==============================================================
source "$SCRIPT_DIR/proxmox.env"

if [[ -z "$API_URL" || -z "$TOKEN_ID" || -z "$TOKEN_SECRET" ]]; then
  echo "❌ Missing required environment variables in proxmox.env"
  exit 1
fi

AUTH_HEADER="Authorization: PVEAPIToken=$TOKEN_ID=$TOKEN_SECRET"


#==============================================================
# Fetch VM list
#==============================================================
echo "Fetching VM list..."
VM_DATA=$(curl -s -k -H "$AUTH_HEADER" "$API_URL/cluster/resources?type=vm")

if [[ -z "$VM_DATA" ]]; then
    echo "❌ Error: Could not retrieve VM list."
    exit 1
fi


#==============================================================
# Build dialog checklist with padded aligned columns (with node)
#==============================================================
MENU_ITEMS=()

MAX_ICON=4      # "[VM]" or "[T]" → constant width
MAX_NAME=0
MAX_STATUS=0
MAX_TAGS=0
MAX_NODE=0

# First pass: determine max column widths
while IFS= read -r vmid; do
    name=$(jq -r ".data[] | select(.vmid==$vmid) | .name // \"(noname)\"" <<< "$VM_DATA")
    status=$(jq -r ".data[] | select(.vmid==$vmid) | .status" <<< "$VM_DATA")
    tags=$(jq -r ".data[] | select(.vmid==$vmid) | .tags // \"\"" <<< "$VM_DATA")
    node=$(jq -r ".data[] | select(.vmid==$vmid) | .node" <<< "$VM_DATA")

    (( ${#name} > MAX_NAME )) && MAX_NAME=${#name}
    (( ${#status} > MAX_STATUS )) && MAX_STATUS=${#status}
    (( ${#tags} > MAX_TAGS )) && MAX_TAGS=${#tags}
    (( ${#node} > MAX_NODE )) && MAX_NODE=${#node}
done < <(jq -r '.data | sort_by((.name//"")|ascii_downcase)[] | .vmid' <<< "$VM_DATA")

# Second pass: construct formatted rows
while IFS= read -r vmid; do
    name=$(jq -r ".data[] | select(.vmid==$vmid) | .name // \"(noname)\"" <<< "$VM_DATA")
    status=$(jq -r ".data[] | select(.vmid==$vmid) | .status" <<< "$VM_DATA")
    tags=$(jq -r ".data[] | select(.vmid==$vmid) | .tags // \"\"" <<< "$VM_DATA")
    node=$(jq -r ".data[] | select(.vmid==$vmid) | .node" <<< "$VM_DATA")
    template=$(jq -r ".data[] | select(.vmid==$vmid) | .template" <<< "$VM_DATA")

    # ASCII icon
    if [[ "$template" == "1" ]]; then
        icon="[T] "
    else
        icon="[VM]"
    fi

    # Pad text fields
    printf -v name_fmt "%-${MAX_NAME}s" "$name"
    printf -v node_fmt "%-${MAX_NODE}s" "$node"
    printf -v tags_fmt "%-${MAX_TAGS}s" "$tags"

    # Status column (templates override)
    if [[ "$template" == "1" ]]; then
        STATUS_FMT="\Z7template\Zn"    # gray
    else
        case "$status" in
            running) STATUS_FMT="\Z2running \Zn" ;;  # green
            stopped) STATUS_FMT="\Z1stopped \Zn" ;;  # red
            *)       STATUS_FMT="\Z3${status}\Zn" ;; # yellow
        esac
    fi

    # Compose final row
    label="${icon} ${name_fmt} | ${node_fmt} | ${STATUS_FMT} |  tags: ${tags_fmt}"

    MENU_ITEMS+=("$vmid" "$label" "off")
done < <(jq -r '.data | sort_by((.name//"")|ascii_downcase)[] | .vmid' <<< "$VM_DATA")


#==============================================================
# Dynamic dialog sizing
#==============================================================
TERM_HEIGHT=$(tput lines)
TERM_WIDTH=$(tput cols)

DIALOG_HEIGHT=$((TERM_HEIGHT - 4))
DIALOG_WIDTH=$((TERM_WIDTH - 4))

(( DIALOG_HEIGHT < 15 )) && DIALOG_HEIGHT=15
(( DIALOG_WIDTH < 60 )) && DIALOG_WIDTH=60

# internal scrollbar list height
AVAILABLE_ROWS=$((DIALOG_HEIGHT - 8))
(( AVAILABLE_ROWS < 5 )) && AVAILABLE_ROWS=5

NUM_VMS=$(( ${#MENU_ITEMS[@]} / 3 ))
(( AVAILABLE_ROWS > NUM_VMS )) && AVAILABLE_ROWS=$NUM_VMS


#==============================================================
# VM Selection Menu
#==============================================================
SELECTED_VMS=$(dialog --colors --clear \
  --title "Proxmox Bulk VM Manager" \
  --checklist "Select VMs to operate on:" \
  "$DIALOG_HEIGHT" "$DIALOG_WIDTH" "$AVAILABLE_ROWS" \
  "${MENU_ITEMS[@]}" \
  3>&1 1>&2 2>&3)

status=$?
clear

if [[ $status -ne 0 ]]; then
    echo "Dialog exit code: $status"
    exit 1
fi


# Remove quotes
SELECTED_VMIDS=$(echo "$SELECTED_VMS" | tr -d '"')

if [[ -z "$SELECTED_VMIDS" ]]; then
    dialog --msgbox "No VMs selected." 10 40
    clear
    exit 0
fi


#==============================================================
# Operation Menu
#==============================================================
OPERATION=$(dialog --clear \
  --menu "Choose an operation:" \
  15 60 4 \
  "shutdown" "Shutdown (ACPI)" \
  "stop"     "Hard stop" \
  "suspend"  "Suspend VM" \
  "delete"   "Delete VM (purge)" \
  3>&1 1>&2 2>&3)

clear

if [[ -z "$OPERATION" ]]; then
    echo "No operation selected."
    exit 0
fi


#==============================================================
# Execute selected operation
#==============================================================
log=""

for vmid in $SELECTED_VMIDS; do
    vmid=$(tr -d '"' <<< "$vmid")
    node=$(jq -r ".data[] | select(.vmid==$vmid) | .node" <<< "$VM_DATA")

    log+="VMID $vmid on node $node → "

    case "$OPERATION" in
        shutdown)
            curl -s -k -X POST -H "$AUTH_HEADER" \
            "$API_URL/nodes/$node/qemu/$vmid/status/shutdown" >/dev/null
            log+="shutdown sent\n"
            ;;
        stop)
            curl -s -k -X POST -H "$AUTH_HEADER" \
            "$API_URL/nodes/$node/qemu/$vmid/status/stop" >/dev/null
            log+="stop sent\n"
            ;;
        suspend)
            curl -s -k -X POST -H "$AUTH_HEADER" \
            "$API_URL/nodes/$node/qemu/$vmid/status/suspend" >/dev/null
            log+="suspend sent\n"
            ;;
        delete)
            curl -s -k -X DELETE -H "$AUTH_HEADER" \
            "$API_URL/nodes/$node/qemu/$vmid?purge=1" >/dev/null
            log+="delete requested\n"
            ;;
    esac
done


#==============================================================
# Results dialog
#==============================================================
dialog --msgbox "$log" 25 90
clear
exit 0
