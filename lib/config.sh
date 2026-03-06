#!/usr/bin/env bash

CONFIG_FILE=""

load_config() {

    if [[ -n "${CONFIG_OVERRIDE:-}" ]]; then
        CONFIG_FILE="$CONFIG_OVERRIDE"
    else
        for path in \
            "$HOME/.config/pve-manager/proxmox.env" \
            "/etc/pve-manager/proxmox.env" \
            "$PROJECT_ROOT/config/proxmox.env"
        do
            if [[ -f "$path" ]]; then
                CONFIG_FILE="$path"
                break
            fi
        done
    fi

    if [[ -z "$CONFIG_FILE" ]]; then
        error "Configuration file not found."
        exit 1
    fi

    # shellcheck source=/dev/null
    source "$CONFIG_FILE"

    AUTH_HEADER="Authorization: PVEAPIToken=$TOKEN_ID=$TOKEN_SECRET"
}