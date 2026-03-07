#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

COMMANDS_DIR="$PROJECT_ROOT/commands"

COMMAND="${1:-help}"

shift || true

COMMAND_PATH="$COMMANDS_DIR/$COMMAND"

if [[ ! -x "$COMMAND_PATH" ]]; then
	echo "Unknown command: $COMMAND"
	exit 1
fi

exec "$COMMAND_PATH" "$@"
