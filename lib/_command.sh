#!/usr/bin/env bash
set -euo pipefail

# Compute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
THEME_DIR="$PROJECT_ROOT/theme"
CONFIG_DIR="$PROJECT_ROOT/config"

# Source common libraries
source "$PROJECT_ROOT/lib/config.sh"
source "$PROJECT_ROOT/lib/api.sh"
source "$PROJECT_ROOT/lib/vm.sh"
source "$PROJECT_ROOT/lib/log.sh"
source "$PROJECT_ROOT/lib/cli.sh"
source "$PROJECT_ROOT/lib/ui.sh"

# Load configuration and VM data
load_config
fetch_vms
