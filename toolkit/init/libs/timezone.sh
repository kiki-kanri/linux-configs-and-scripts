#!/usr/bin/env bash

# shellcheck shell=bash

# Constants/Variables
readonly DEFAULT_TIMEZONE='Asia/Taipei'
readonly -a COMMON_TIMEZONES=(Asia/Taipei Asia/Hong_Kong Asia/Tokyo UTC)

# Functions
timezone_exists() {
    local timezone="$1"

    [[ "${timezone}" != /* && "${timezone}" != *../* && -f "/usr/share/zoneinfo/${timezone}" ]]
}

read_timezone() {
    local timezone

    if [[ ! -r /dev/tty ]]; then
        log_info "No interactive terminal; using default timezone: ${DEFAULT_TIMEZONE}" >&2
        printf '%s\n' "${DEFAULT_TIMEZONE}"
        return 0
    fi

    printf 'Common timezones: %s\n' "${COMMON_TIMEZONES[*]}" >&2
    while true; do
        printf 'Enter timezone [%s]: ' "${DEFAULT_TIMEZONE}" >/dev/tty
        read -r timezone </dev/tty || return 1
        timezone="${timezone:-${DEFAULT_TIMEZONE}}"
        if timezone_exists "${timezone}"; then
            printf '%s\n' "${timezone}"
            return 0
        fi

        log_error "Unknown timezone: ${timezone}"
    done
}
