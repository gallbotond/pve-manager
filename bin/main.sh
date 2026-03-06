#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

LIB_DIR="$PROJECT_ROOT/lib"

# global paths
export THEME_DIR="$PROJECT_ROOT/theme"
export CONFIG_DIR="$PROJECT_ROOT/config"

# global flags
export DRY_RUN=false
export FORCE=false
export VERBOSE=false

source "$LIB_DIR/log.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/api.sh"
source "$LIB_DIR/vm.sh"
source "$LIB_DIR/ui.sh"
source "$LIB_DIR/cli.sh"

main() {
	parse_args "$@"
	load_config
	fetch_vms
	run_command
}

main "$@"
