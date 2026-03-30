#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# setup-timezone.sh — Set system timezone
#
# Usage:
#   setup-timezone.sh [timezone]   # e.g. Asia/Taipei, America/New_York
#   setup-timezone.sh             # interactive mode (menu)

set -Eeuo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root

TZ_DIR="/usr/share/zoneinfo"
TZ_FILE="/etc/timezone"
LOCALTIME="/etc/localtime"

do_setup() {
    local tz="$1"

    if [[ ! -f "${TZ_DIR}/${tz}" ]]; then
        log_error "Timezone ${tz} is not available."
        return 1
    fi

    log_info "Setting timezone to ${tz}..."

    # Update timezone file
    echo "${tz}" >"${TZ_FILE}"

    # Update localtime symlink
    ln -sf "${TZ_DIR}/${tz}" "${LOCALTIME}"

    # Tell tzdata to update
    dpkg-reconfigure -f noninteractive tzdata 2>/dev/null || true

    log_success "Timezone set to ${tz}."
    log_info "Current time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
}

main() {
    local tz=""

    if [[ $# -gt 0 ]] && [[ -n "$1" ]]; then
        tz="$1"
    else
        log_info "Current timezone: $(cat "${TZ_FILE}" 2>/dev/null || echo 'not set')"
        echo
        log_info "Common timezones:"
        echo "  Asia/Taipei"
        echo "  Asia/Shanghai"
        echo "  Asia/Tokyo"
        echo "  Europe/London"
        echo "  Europe/Berlin"
        echo "  America/New_York"
        echo "  America/Los_Angeles"
        echo "  UTC"
        echo
        read -rp "Enter timezone: " tz </dev/tty
        if [[ -z "${tz}" ]]; then
            log_error "Timezone is required."
            return 1
        fi
    fi

    if [[ ! -f "${TZ_DIR}/${tz}" ]]; then
        log_error "Timezone ${tz} not found in ${TZ_DIR}/."
        return 1
    fi

    confirm "Set timezone to ${tz}?" --default=yes || exit 0
    do_setup "${tz}"
}

main "$@"
