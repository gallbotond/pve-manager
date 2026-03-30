# Agent Guidelines for pve-manager

## Project Overview

Terminal UI for bulk managing Proxmox VMs using the Proxmox VE API. Written in Bash.

## Build/Lint/Test Commands

```bash
# Run all checks (lint + test)
make check

# Lint all shell scripts
make lint

# Strict lint (errors only, no warnings)
make lint-ci

# Run tests
make test

# Run a single test file
bats tests/cli.bats

# Run a single test
bats tests/cli.bats --filter "VMID displayed"

# Format code
make fmt

# Syntax check only (no execution)
bash -n bin/pm.sh
bash -n lib/*.sh
```

## Code Style

### Shebang and Script Headers
- All scripts must start with `#!/usr/bin/env bash`
- Main entry points and command scripts must include `set -euo pipefail`

### Indentation
- Use **tabs** for indentation (enforced by shfmt)
- Do not add extra indentation to align `=` signs or similar

### File Structure
```
bin/          - Main entry point (pm.sh)
lib/          - Shared libraries (sourced via source)
  _command.sh - Common setup for command scripts
  api.sh      - Proxmox API calls
  cli.sh      - CLI argument parsing
  config.sh   - Configuration loading
  log.sh      - Logging utilities
  ui.sh       - Dialog TUI
  vm.sh       - VM operations
commands/     - Executable command scripts (list, shutdown, stop, etc.)
tests/        - BATS tests
  fixtures/   - JSON test data
  mocks/      - Mock executables for testing
```

### Imports/Dependencies
- Source files using relative paths from PROJECT_ROOT
- Command scripts source `lib/_command.sh` which loads all dependencies
- Use shellcheck directive `shellcheck source=/dev/null` when sourcing config files

### Variable Naming
- Global constants: `UPPER_CASE` (e.g., `API_URL`, `AUTH_HEADER`)
- Function-local variables: `lower_case` (e.g., `local response`)
- Avoid globals in library functions; pass data explicitly

### Function Naming
- Use `snake_case` (e.g., `fetch_vms`, `vm_action`, `parse_args`)
- Private/helper functions may start with `_` (e.g., `_internal_func`)

### Error Handling
- Use `error()` for user-facing errors (logs to stderr)
- Use `warn()` for warnings
- Use `log()` for informational output
- Use `debug()` for verbose debugging (only when `VERBOSE=true`)
- Exit with code 1 on fatal errors: `exit 1`
- Prefer early returns over deep nesting

### Conditionals
- Use `[[ ]]` for all shell tests (not `[ ]` or `test`)
- Quote variables: `[[ "$var" == "value" ]]`
- Use `[[ -z "$var" ]]` to check for empty strings
- Use `[[ -f "$path" ]]` to check file existence
- Use `&&` and `||` for short-circuit evaluation where appropriate

### API Calls
- Use `curl -s -k` for Proxmox API requests
- Always include `-H "$AUTH_HEADER"`
- Store responses in variables, not command substitution for complex parsing

### Testing
- Use BATS framework
- Use `setup()` to configure test environment
- Use `PVE_MANAGER_TEST_DATA` env var to inject fixture JSON
- Mock external commands (curl) by placing in `tests/mocks/` and prepending to PATH
- Verify behavior, not implementation (test outputs, not internal state)

### Common Patterns

**Checking command exists:**
```bash
if ! command -v dialog >/dev/null 2>&1; then
    echo "Error: 'dialog' is not installed."
    exit 1
fi
```

**Parsing command-line args:**
```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--dry-run)
        DRY_RUN=true
        ;;
    *)
        ARGS+=("$1")
        ;;
    esac
    shift
done
```

**Looping over arguments:**
```bash
for vmid in "$@"; do
    # process vmid
done
```

**JQ queries:**
```bash
jq -r '.data[] | select(.vmid==$vmid) | .node' <<<"$VM_DATA"
```

**Exit with message:**
```bash
error "Something went wrong"
exit 1
```

### What to Avoid
- Do not use `echo` for errors (use `error` function)
- Do not use backticks (use `$()`)
- Do not use `set -x` in production code
- Do not commit secrets or credentials
- Do not use `eval` unless absolutely necessary
