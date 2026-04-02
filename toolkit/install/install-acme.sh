#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# install-acme.sh — Install acme.sh (Let's Encrypt / ACME client)
#
# Installs via git clone + acme.sh's own --install target.
# The acme.sh installer handles everything (cron, paths, etc.) automatically.
#
# Supports both root and non-root installation.
# Re-running wipes ~/.acme.sh and re-installs from scratch.

set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_cmd git curl

ACMEREPO="https://github.com/acmesh-official/acme.sh.git"
TMPDIR="/tmp/acme.sh"
ACMEDIR="${HOME}/.acme.sh"
ACMEBIN="${ACMEDIR}/acme.sh"

do_install() {
    local email="$1"
    local reinstall=false

    if [[ -x "${ACMEBIN}" ]]; then
        reinstall=true
        log_info "acme.sh is already installed. Re-installing from scratch..."
    fi

    # Always start clean — wipe ~/.acme.sh if it exists
    if [[ -e "${ACMEDIR}" ]]; then
        log_info "Removing existing ${ACMEDIR}..."
        rm -rf "${ACMEDIR}"
    fi

    # Install cron first, before cloning
    log_info "Installing cron..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y cron 2>/dev/null || true
    fi

    # Clone and install
    log_info "Cloning acme.sh to ${TMPDIR}..."
    rm -rf "${TMPDIR}"
    git clone "${ACMEREPO}" "${TMPDIR}"

    log_info "Running acme.sh installer (email: ${email})..."
    (
        cd "${TMPDIR}"
        ./acme.sh --install -m "${email}"
    )
    rm -rf "${TMPDIR}"

    log_info "Setting default CA to letsencrypt..."
    "${ACMEBIN}" --set-default-ca --server letsencrypt

    log_info "Enabling auto-upgrade..."
    "${ACMEBIN}" --upgrade --auto-upgrade

    log_success "acme.sh installed to ${ACMEDIR}/"
    log_info "Access via: ${ACMEBIN}"
    log_info "Account email : ${email}"
}

main() {
    local email=""

    if [[ -x "${ACMEBIN}" ]]; then
        local installed_version
        installed_version="$("${ACMEBIN}" --version 2>/dev/null | head -1 || echo "unknown")"
        log_info "acme.sh is already installed (${installed_version})."
        confirm "Re-install from scratch?" --default=no || exit 0
    fi

    if [[ $# -gt 0 ]] && [[ -n "$1" ]]; then
        email="$1"
    else
        log_info "Installing acme.sh requires an email for your Let's Encrypt account."
        read -rp "Enter your email address: " email </dev/tty
        if [[ -z "${email}" ]]; then
            log_error "Email is required."
            exit 1
        fi
    fi

    if [[ ! "${email}" =~ .+@.+ ]]; then
        log_error "Invalid email address: ${email}"
        exit 1
    fi

    do_install "${email}"
}

main "$@"
