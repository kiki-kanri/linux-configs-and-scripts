#!/usr/bin/env bash
# Install Cloudflare real IP updater for nginx and run it once.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

UPDATER_NAME="update-cloudflare-realip-nginx"
SERVICE_NAME="cloudflare-realip-nginx-update.service"
TIMER_NAME="cloudflare-realip-nginx-update.timer"
UPDATER_SRC="${REPO_ROOT}/toolkit/service/${UPDATER_NAME}.sh"
UPDATER_DEST="/usr/local/sbin/${UPDATER_NAME}"
SERVICE_SRC="${REPO_ROOT}/toolkit/conf/systemd/${SERVICE_NAME}"
TIMER_SRC="${REPO_ROOT}/toolkit/conf/systemd/${TIMER_NAME}"
NGINX_REALIP_DIR="/etc/nginx/conf.d"

if (($# > 0)); then
    log_error "Unexpected argument: $1"
    exit 1
fi

require_root
require_cmd apt-get chmod cp install mkdir
require_file "${UPDATER_SRC}"
require_file "${SERVICE_SRC}"
require_file "${TIMER_SRC}"

missing_packages=()
command_exists curl || missing_packages+=(curl)
command_exists python3 || missing_packages+=(python3)

if ((${#missing_packages[@]} > 0)); then
    log_info "Installing updater dependencies: ${missing_packages[*]}"
    apt-get update
    apt-get install -y --no-install-recommends "${missing_packages[@]}"
fi

log_info "Installing Cloudflare real IP updater..."
install_file "${UPDATER_SRC}" "${UPDATER_DEST}" 755
install -d -m 755 "${NGINX_REALIP_DIR}"
install_file "${SERVICE_SRC}" "/etc/systemd/system/${SERVICE_NAME}" 644
install_file "${TIMER_SRC}" "/etc/systemd/system/${TIMER_NAME}" 644

if command_exists systemctl; then
    systemctl daemon-reload
    systemctl enable --now "${TIMER_NAME}"
else
    log_warn "systemctl not found; timer was installed but not enabled."
fi

log_info "Running Cloudflare real IP update now..."
"${UPDATER_DEST}"

log_success "Cloudflare real IP auto-update is configured for nginx."
