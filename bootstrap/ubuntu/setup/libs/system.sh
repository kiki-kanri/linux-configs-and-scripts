#!/usr/bin/env bash

# shellcheck shell=bash

# Functions
read_timezone() {
    local timezone

    while true; do
        printf 'Enter timezone [Asia/Taipei]: ' >/dev/tty
        read -r timezone </dev/tty || return 1
        timezone="${timezone:-Asia/Taipei}"
        if [[ -f "/usr/share/zoneinfo/${timezone}" ]]; then
            printf '%s\n' "${timezone}"
            return 0
        fi

        log_error "Invalid timezone: ${timezone}"
    done
}

enable_rc_local() {
    log_info 'Enabling rc.local...'
    systemctl enable rc-local.service
}

configure_bootstrap_system() {
    local timezone="$1"

    enable_rc_local
    "${TOOLKIT_DIR}/init/disable-motds.sh"
    "${TOOLKIT_DIR}/init/disable-ipv6.sh"
    "${TOOLKIT_DIR}/init/setup-locale.sh" -f en_US.UTF-8
    "${TOOLKIT_DIR}/init/setup-timezone.sh" -f "${timezone}"
}
