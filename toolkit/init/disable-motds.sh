#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly -a MOTD_SCRIPTS=(
    /etc/update-motd.d/00-header
    /etc/update-motd.d/10-help-text
    /etc/update-motd.d/50-landscape-sysinfo
    /etc/update-motd.d/50-motd-news
    /etc/update-motd.d/80-edk2-ovmf
    /etc/update-motd.d/90-updates-available
    /etc/update-motd.d/91-apt-dracles
    /etc/update-motd.d/95-hwe-eol
    /etc/update-motd.d/98-reboot-required
)

# Run
main() {
    local script
    local failed=false

    require_root
    for script in "${MOTD_SCRIPTS[@]}"; do
        [[ -e "${script}" ]] || continue
        if chmod a-x -- "${script}"; then
            log_info "Disabled MOTD script: ${script}"
        else
            log_warn "Could not disable MOTD script: ${script}"
            failed=true
        fi
    done

    if "${failed}"; then
        log_warn 'MOTD setup completed with failures; some scripts remain enabled'
    else
        log_success 'Selected MOTD scripts disabled'
    fi
}

main "$@"
