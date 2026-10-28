#!/usr/bin/env bash

# shellcheck shell=bash

# shellcheck disable=SC1091
source "${REPO_ROOT}/toolkit/init/libs/timezone.sh"

# Functions
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
