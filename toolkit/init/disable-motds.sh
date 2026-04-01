#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# disable-motds.sh — Disable MOTD (Message of the Day) login banners

set -Eeuo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root

# Files to chmod -x in update-motd.d
MOTD_SCRIPTS=(
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

# TODO: exit error ?
main() {
    log_info "Disabling update-motd.d scripts..."
    local disabled=0
    for script in "${MOTD_SCRIPTS[@]}"; do
        if [[ -f "${script}" ]]; then
            chmod -x "${script}" 2>/dev/null || true
            ((disabled++))
        fi
    done
    log_info "Disabled ${disabled} MOTD scripts."

    # Clear static /etc/motd
    if [[ -f /etc/motd ]]; then
        : >/etc/motd
        log_info "Cleared /etc/motd."
    fi

    # Disable systemd motd service if present
    if command -v systemctl >/dev/null 2>&1; then
        systemctl mask --now serial-getty@ttyS0.service >/dev/null 2>&1 || true
        # Mask the motd news service if it exists
        if systemctl list-unit-files | grep -q 'motd-news.service'; then
            systemctl mask --now motd-news.service >/dev/null 2>&1 || true
            log_info "Masked motd-news.service."
        fi
    fi

    log_success "MOTD disabled."
}

main "$@"
