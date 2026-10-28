#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly DEFAULT_TIMEZONE='Asia/Taipei'
readonly -a COMMON_TIMEZONES=(Asia/Taipei Asia/Hong_Kong Asia/Tokyo UTC)

# Functions
prompt_timezone() {
    local selected_timezone current_timezone

    current_timezone="$(timedatectl show -p Timezone --value)" || return 1
    log_info "Current timezone: ${current_timezone}" >&2
    printf 'Common timezones: %s\n' "${COMMON_TIMEZONES[*]}" >&2
    if [[ -r /dev/tty ]]; then
        printf 'Enter timezone [%s]: ' "${DEFAULT_TIMEZONE}" >/dev/tty
        read -r selected_timezone </dev/tty || return 1
    else
        log_info "No interactive terminal; using default timezone: ${DEFAULT_TIMEZONE}" >&2
        selected_timezone="${DEFAULT_TIMEZONE}"
    fi
    printf '%s\n' "${selected_timezone:-${DEFAULT_TIMEZONE}}"
}

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
    [[ -n "${timezone}" ]] || timezone="$(prompt_timezone)"
    if [[ "${timezone}" == /* || "${timezone}" == *../* || ! -f "/usr/share/zoneinfo/${timezone}" ]]; then
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
