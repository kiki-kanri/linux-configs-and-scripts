#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# Configure the system timezone on Debian/Ubuntu.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

TZ_DIR="/usr/share/zoneinfo"
TZ_FILE="/etc/timezone"
LOCALTIME="/etc/localtime"
DEFAULT_TZ="Asia/Taipei"
COMMON_TIMEZONES=(
    Asia/Taipei
    Asia/Hong_Kong
    Asia/Tokyo
    UTC
)

force=false
timezone=""

current_timezone() {
    timedatectl show -p Timezone --value 2>/dev/null || cat "${TZ_FILE}" 2>/dev/null || printf 'not set\n'
}

timezone_exists() {
    local tz="$1"
    [[ "${tz}" != /* && "${tz}" != *../* && -f "${TZ_DIR}/${tz}" ]]
}

prompt_timezone() {
    local selected_timezone=""

    {
        log_info "Current timezone: $(current_timezone)"
        echo
        log_info "Common timezones:"
        printf '  %s\n' "${COMMON_TIMEZONES[@]}"
        echo
    } >&2

    if [[ -r /dev/tty ]]; then
        printf 'Enter timezone [%s]: ' "${DEFAULT_TZ}" >/dev/tty
        read -r selected_timezone </dev/tty || selected_timezone=""
    else
        log_warn "No interactive terminal; using default timezone: ${DEFAULT_TZ}"
        selected_timezone="${DEFAULT_TZ}"
    fi

    printf '%s\n' "${selected_timezone:-${DEFAULT_TZ}}"
}

while (($# > 0)); do
    case "$1" in
    -f)
        force=true
        shift
        ;;
    -*)
        log_error "Unknown option: $1"
        exit 1
        ;;
    *)
        if [[ -n "${timezone}" ]]; then
            log_error "Unexpected extra argument: $1"
            exit 1
        fi
        timezone="$1"
        shift
        ;;
    esac
done

require_root

[[ -n "${timezone}" ]] || timezone="$(prompt_timezone)"

if ! timezone_exists "${timezone}"; then
    log_error "Timezone ${timezone} is not available in ${TZ_DIR}."
    exit 1
fi

if [[ "${force}" == false ]]; then
    confirm "Set timezone to ${timezone}?" --default=yes || exit 0
else
    log_info "Force mode: skipping confirmation."
fi

log_info "Setting timezone to ${timezone}..."
printf '%s\n' "${timezone}" >"${TZ_FILE}"
ln -sfn "${TZ_DIR}/${timezone}" "${LOCALTIME}"

if command_exists timedatectl; then
    timedatectl set-timezone "${timezone}" 2>/dev/null || true
fi

dpkg-reconfigure -f noninteractive tzdata 2>/dev/null || true

log_success "Timezone set to ${timezone}."
log_info "Current local time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
