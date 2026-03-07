#!/usr/bin/env bash
set -euo pipefail

# Compute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source common libraries
source "$PROJECT_ROOT/lib/config.sh"
source "$PROJECT_ROOT/lib/api.sh"
source "$PROJECT_ROOT/lib/vm.sh"
source "$PROJECT_ROOT/lib/log.sh"

# Load configuration and VM data
load_config
fetch_vms
