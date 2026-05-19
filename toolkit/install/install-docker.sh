#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# Install or refresh Docker Engine with Docker's official installer.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

INSTALL_URL="https://get.docker.com"
force=false
installer=""

cleanup() {
    [[ -z "${installer}" ]] || rm -f "${installer}"
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
        log_error "Unexpected argument: $1"
        exit 1
        ;;
    esac
done

require_root
require_cmd curl sh mktemp rm

if command_exists docker && [[ "${force}" == false ]]; then
    log_info "Docker is already installed: $(docker --version 2>/dev/null || printf 'version unknown')"
    log_info "Use -f to run Docker's installer again."
else
    installer="$(mktemp)"
    trap cleanup EXIT

    log_info "Downloading Docker official installer..."
    curl -fsSL --output "${installer}" "${INSTALL_URL}"

    log_info "Running Docker official installer..."
    sh "${installer}"
    log_success "Docker installer completed."
fi

if command_exists systemctl; then
    log_info "Enabling and starting Docker service..."
    systemctl enable --now docker || log_warn "Could not enable/start Docker service. Check systemd status manually."
else
    log_warn "systemctl not found; skipping Docker service enable/start."
fi

log_info "Docker version: $(docker --version 2>/dev/null || printf 'N/A')"
log_info "Compose version: $(docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || printf 'N/A')"
