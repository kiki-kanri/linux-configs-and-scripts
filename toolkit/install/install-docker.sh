#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# install-docker.sh — Install Docker Engine via the official installer
#
# Uses the official Docker install script:
#   https://github.com/docker/docker-install
#   curl -fsSL https://get.docker.com | sh
#
# Installs: Docker Engine, Docker CLI, Docker Buildx, Docker Compose, containerd, runc

set -Eeuo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root
require_cmd curl

do_install() {
    log_info "Running official Docker installation script..."
    log_info "(curl -fsSL https://get.docker.com | sh)"

    if ! curl -fsSL https://get.docker.com | sh; then
        log_error "Docker installation failed."
        exit 1
    fi

    log_success "Docker installed."
}

post_install() {
    # Add current user to docker group so sudo is not required
    local user="${SUDO_USER:-${USER}}"

    if [[ -n "${user}" ]] && [[ "${user}" != "root" ]]; then
        if ! groups "${user}" | grep -q docker; then
            log_info "Adding ${user} to docker group..."
            usermod -aG docker "${user}"
            log_success "User ${user} added to docker group."
            log_warn "Log out and back in for group change to take effect."
        else
            log_info "User ${user} is already in docker group."
        fi
    fi

    # Enable Docker service
    systemctl enable --now docker 2>/dev/null || true

    log_info "Docker version: $(docker --version 2>/dev/null || echo 'N/A')"
    log_info "Compose version: $(docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo 'N/A')"
}

main() {
    if command -v docker >/dev/null 2>&1; then
        log_info "Docker is already installed: $(docker --version 2>/dev/null || echo '')"
        confirm "Re-run official installer?" --default=no || exit 0
    fi

    do_install
    post_install
}

main "$@"
