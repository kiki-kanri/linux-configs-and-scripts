#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# setup-timezone.sh — Set system timezone
#
# Usage:
#   setup-timezone.sh [-y] [timezone]   # e.g. -y Asia/Taipei
#   setup-timezone.sh                   # interactive mode

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
DEFAULT_TZ="Asia/Taipei"

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

    # Tell tzdata to update (Debian/Ubuntu)
    dpkg-reconfigure -f noninteractive tzdata 2>/dev/null || true

    log_success "Timezone set to ${tz}."
    log_info "Current local time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
}

main() {
    local tz=""
    local skip_confirm=false

    while getopts "y" opt; do
        case $opt in
        y) skip_confirm=true ;;
        *) ;;
        esac
    done
    shift $((OPTIND - 1))

    if [[ -n "${1:-}" ]]; then
        tz="$1"
    else
        log_info "Current timezone: $(cat "${TZ_FILE}" 2>/dev/null || echo 'not set')"
        echo
        log_info "Common timezones:"
        echo "  Asia/Taipei (Default)"
        echo "  Asia/Hong_Kong"
        echo "  Asia/Tokyo"
        echo "  UTC"
        echo
        read -rp "Enter timezone [${DEFAULT_TZ}]: " tz </dev/tty
        [[ -z "${tz}" ]] && tz="${DEFAULT_TZ}"
    fi

    if [[ ! -f "${TZ_DIR}/${tz}" ]]; then
        log_error "Timezone ${tz} not found in ${TZ_DIR}/."
        return 1
    fi

    if [ "$skip_confirm" = false ]; then
        confirm "Set timezone to ${tz}?" --default=yes || exit 0
    else
        log_info "Automatic mode: skipping confirmation."
    fi

    do_setup "${tz}"
}

main "$@"
