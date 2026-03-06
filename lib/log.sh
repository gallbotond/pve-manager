#!/usr/bin/env bash

LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/pve-manager.log"
mkdir -p "$(dirname "$LOG_FILE")"

VERBOSE=false

log() {
	echo "[INFO] $*" | tee -a "$LOG_FILE"
}

warn() {
	echo "[WARN] $*" | tee -a "$LOG_FILE" >&2
}

error() {
	echo "[ERROR] $*" | tee -a "$LOG_FILE" >&2
}

debug() {
	[[ "$VERBOSE" == true ]] && echo "[DEBUG] $*" | tee -a "$LOG_FILE"
}
