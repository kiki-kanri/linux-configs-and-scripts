#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"
source "${SCRIPT_DIR}/libs/timezone.sh"

# Run
main() {
    local force=false
    local timezone=''

    while (($# > 0)); do
        case "$1" in
        -f) force=true ;;
        -*)
            log_error "Unknown option: $1"
            exit 2
            ;;
        *)
            if [[ -n "${timezone}" ]]; then
                log_error "Unexpected argument: $1"
                exit 2
            fi
            timezone="$1"
            ;;
        esac

        shift
    done

    require_root
    require_cmd timedatectl
    if [[ -z "${timezone}" ]]; then
        read_timezone timezone
    fi

    if ! timezone_exists "${timezone}"; then
        log_error "Unknown timezone: ${timezone}"
        exit 1
    fi

    if [[ "${force}" == false ]]; then
        confirm "Set timezone to ${timezone}?" --default=yes || return 0
    fi

    log_info "Setting timezone: ${timezone}..."
    timedatectl set-timezone "${timezone}"
    log_success "Timezone set: ${timezone}"
}

main "$@"
