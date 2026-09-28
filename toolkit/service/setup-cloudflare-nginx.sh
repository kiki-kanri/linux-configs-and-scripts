#!/usr/bin/env bash
# Install Cloudflare IP range updater for nginx and run it once.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

UPDATER_NAME="update-cloudflare-nginx"
SERVICE_NAME="cloudflare-nginx-update.service"
TIMER_NAME="cloudflare-nginx-update.timer"
UPDATER_SRC="${REPO_ROOT}/toolkit/service/${UPDATER_NAME}.sh"
UPDATER_DEST="/usr/local/sbin/${UPDATER_NAME}"
SERVICE_SRC="${REPO_ROOT}/toolkit/conf/systemd/${SERVICE_NAME}"
TIMER_SRC="${REPO_ROOT}/toolkit/conf/systemd/${TIMER_NAME}"
ACCESS_SRC="${REPO_ROOT}/toolkit/conf/nginx/public/access/cloudflare-only.conf"
ACCESS_DEST="/etc/nginx/public/access/cloudflare-only.conf"
NGINX_CONF_DIR="/etc/nginx/conf.d"
OLD_SERVICE="cloudflare-realip-nginx-update.service"
OLD_TIMER="cloudflare-realip-nginx-update.timer"
OLD_UPDATER="/usr/local/sbin/update-cloudflare-realip-nginx"
OLD_CONF="${NGINX_CONF_DIR}/cloudflare-realip.conf"

if (($# > 0)); then
    log_error "Unexpected argument: $1"
    exit 1
fi

require_root
require_cmd apt-get chmod cp dirname install mkdir rm
require_file "${UPDATER_SRC}"
require_file "${SERVICE_SRC}"
require_file "${TIMER_SRC}"
require_file "${ACCESS_SRC}"

missing_packages=()
command_exists curl || missing_packages+=(curl)
command_exists python3 || missing_packages+=(python3)

if ((${#missing_packages[@]} > 0)); then
    log_info "Installing updater dependencies: ${missing_packages[*]}"
    apt-get update
    apt-get install -y --no-install-recommends "${missing_packages[@]}"
fi

log_info "Installing Cloudflare nginx updater..."
install_file "${UPDATER_SRC}" "${UPDATER_DEST}" 755
install -d -m 755 "${NGINX_CONF_DIR}"
install -d -m 755 "$(dirname -- "${ACCESS_DEST}")"
install_file "${ACCESS_SRC}" "${ACCESS_DEST}" 644
install_file "${SERVICE_SRC}" "/etc/systemd/system/${SERVICE_NAME}" 644
install_file "${TIMER_SRC}" "/etc/systemd/system/${TIMER_NAME}" 644

if command_exists systemctl && [[ -f "/etc/systemd/system/${OLD_TIMER}" ]]; then
    systemctl disable --now "${OLD_TIMER}"
    if systemctl is-active --quiet "${OLD_SERVICE}"; then
        systemctl stop "${OLD_SERVICE}"
    fi
fi

rm -f "${OLD_CONF}" "/etc/systemd/system/${OLD_SERVICE}" "/etc/systemd/system/${OLD_TIMER}" "${OLD_UPDATER}"

log_info "Running Cloudflare nginx update now..."
"${UPDATER_DEST}"

if command_exists systemctl; then
    systemctl daemon-reload
    systemctl enable --now "${TIMER_NAME}"
else
    log_warn "systemctl not found; timer was installed but not enabled."
fi

log_success "Cloudflare nginx IP range auto-update is configured."
