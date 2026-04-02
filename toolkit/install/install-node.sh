#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# install-node.sh — Install Node.js 24.x via NodeSource
#
# Uses the official NodeSource setup script.
# Supports: Debian, Ubuntu (x86_64 + aarch64/arm64)

set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root
require_cmd curl

NODE_VERSION="24.x"
NODESOURCE_SETUP_URL="https://deb.nodesource.com/setup_${NODE_VERSION}"
CRON_SRC="${SCRIPT_DIR}/../conf/cron.daily/npm-upgrade"
CRON_DEST="/etc/cron.daily/npm-upgrade"

do_install() {
    log_info "Setting up NodeSource repository for Node.js ${NODE_VERSION}..."

    if ! curl -fsSL "${NODESOURCE_SETUP_URL}" | bash -; then
        log_error "NodeSource setup failed."
        return 1
    fi

    log_info "Installing nodejs..."
    apt-get update
    apt-get install -y nodejs

    log_success "Node.js installed."
}

post_install() {
    log_info "Node version : $(node --version 2>/dev/null || echo 'N/A')"
    log_info "npm version  : $(npm --version 2>/dev/null || echo 'N/A')"
    log_info "pnpm version : $(pnpm --version 2>/dev/null || echo 'N/A')"

    if ! command -v npm >/dev/null 2>&1; then
        log_warn "npm not found — skipping npm and cron setup."
        return 0
    fi

    log_info "Updating global npm packages..."
    npm install -g npm@latest 2>/dev/null || true
}

install_cron() {
    log_info "Ensuring cron is installed..."
    apt-get install -y cron 2>/dev/null || true

    log_info "Installing npm-upgrade cron job..."
    cp -f "${CRON_SRC}" "${CRON_DEST}"
    chmod +x "${CRON_DEST}"
    log_success "Cron job installed: ${CRON_DEST}"
}

run_cron_now() {
    log_info "Running npm-upgrade now..."
    bash "${CRON_DEST}"
}

main() {
    if command -v node >/dev/null 2>&1; then
        log_info "Node.js is already installed: $(node --version)"
        confirm "Re-install?" --default=no || exit 0
    fi

    do_install
    post_install
    install_cron
    run_cron_now

    log_success "Node.js setup complete."
}

main "$@"
