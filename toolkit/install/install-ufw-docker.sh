#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# install-ufw-docker.sh — Install ufw-docker utility
#
# ufw-docker is a tool that makes UFW work properly with Docker.
# It configures UFW to not interfere with Docker's container networking.
#
# Ref: https://github.com/chaifeng/ufw-docker
#
# Prerequisites:
#   - ufw must be installed AND active
#   - if ufw is not installed or not active, this script skips silently

set -Eeuo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root

do_install() {
    # ── Pre-flight: ufw must be installed ───────────────────────
    if ! command -v ufw >/dev/null 2>&1; then
        log_info "ufw is not installed — skipping ufw-docker."
        return 0
    fi

    if ! systemctl is-active --quiet ufw 2>/dev/null; then
        log_info "ufw is not running — skipping ufw-docker."
        log_info "Start ufw with: ufw enable"
        return 0
    fi

    log_info "ufw is active — proceeding with ufw-docker installation..."

    # ── Download ufw-docker ──────────────────────────────────────
    local url="https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker"
    local dest="/usr/local/bin/ufw-docker"

    log_info "Downloading ufw-docker from ${url}..."
    if ! curl -fsSL --output "${dest}" "${url}"; then
        log_error "Download failed."
        return 1
    fi
    chmod +x "${dest}"

    # ── Install ──────────────────────────────────────────────────
    log_info "Running ufw-docker install..."
    if ! ufw-docker install; then
        log_error "ufw-docker install failed."
        rm -f "${dest}"
        return 1
    fi

    # ── Restart ufw ──────────────────────────────────────────────
    systemctl restart ufw
    ufw reload

    log_success "ufw-docker installed to ${dest}"
}

main() {
    do_install
}

main "$@"
