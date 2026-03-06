#!/usr/bin/env bash

COMMAND="ui"
ARGS=()

parse_args() {

    COMMAND="${1:-ui}"
    shift || true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run)
                DRY_RUN=true
                ;;
            -v|--verbose)
                VERBOSE=true
                ;;
            -y|--yes)
                FORCE=true
                ;;
            -c|--config)
                CONFIG_OVERRIDE="$2"
                shift
                ;;
            *)
                ARGS+=("$1")
                ;;
        esac
        shift
    done
}

run_command() {

    case "$COMMAND" in

        ui)
            run_ui
            ;;

        list)
            list_vms
            ;;

        shutdown|stop|suspend|delete)
            vm_action "$COMMAND" "${ARGS[@]}"
            ;;

        *)
            error "Unknown command: $COMMAND"
            exit 1
            ;;

    esac
}

confirm() {

    if [[ "${FORCE:-false}" == true ]]; then
        return
    fi

    read -rp "$1 [y/N]: " ans

    if [[ "$ans" != "y" ]]; then
        echo "Aborted."
        exit 1
    fi
}