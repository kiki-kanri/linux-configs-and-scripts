#!/usr/bin/env bash
# Install ufw-docker when UFW is installed and active.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

UFW_DOCKER_URL="https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker"
UFW_DOCKER_BIN="/usr/local/bin/ufw-docker"
tmp=""

cleanup() {
    [[ -z "${tmp}" ]] || rm -f "${tmp}"
}

ufw_is_active() {
    if command_exists systemctl && systemctl is-active --quiet ufw 2>/dev/null; then
        return 0
    fi

    ufw status 2>/dev/null | grep -qi '^Status:[[:space:]]*active'
}

if (($# > 0)); then
    log_error "Unexpected argument: $1"
    exit 1
fi

require_root
require_cmd curl grep install mktemp rm

if ! command_exists ufw; then
    log_info "UFW is not installed; skipping ufw-docker."
    exit 0
fi

if ! ufw_is_active; then
    log_info "UFW is not active; skipping ufw-docker."
    log_info "Enable UFW first, then rerun this script."
    exit 0
fi

tmp="$(mktemp)"
trap cleanup EXIT

log_info "Downloading ufw-docker..."
curl -fsSL --output "${tmp}" "${UFW_DOCKER_URL}"
install -m 755 "${tmp}" "${UFW_DOCKER_BIN}"

log_info "Applying ufw-docker rules..."
if ! "${UFW_DOCKER_BIN}" install; then
    log_error "ufw-docker install failed."
    rm -f "${UFW_DOCKER_BIN}"
    exit 1
fi

if command_exists systemctl; then
    systemctl restart ufw 2>/dev/null || log_warn "Could not restart ufw with systemctl."
fi
ufw reload

log_success "ufw-docker installed: ${UFW_DOCKER_BIN}"
