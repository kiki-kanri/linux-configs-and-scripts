#!/usr/bin/env bash

# shellcheck disable=SC1091

# Install Cloudflare IP range updater for nginx and run it once.

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly ACCESS_DEST='/etc/nginx/public/access/cloudflare-only.conf'
readonly ACCESS_SRC="${REPO_ROOT}/toolkit/conf/nginx/public/access/cloudflare-only.conf"
readonly NGINX_CONF_DIR='/etc/nginx/conf.d'
readonly SERVICE_NAME='cloudflare-nginx-update.service'
readonly SERVICE_SRC="${REPO_ROOT}/toolkit/conf/systemd/${SERVICE_NAME}"
readonly TIMER_NAME='cloudflare-nginx-update.timer'
readonly TIMER_SRC="${REPO_ROOT}/toolkit/conf/systemd/${TIMER_NAME}"
readonly UPDATER_NAME='update-cloudflare-nginx'
readonly UPDATER_SRC="${REPO_ROOT}/toolkit/service/${UPDATER_NAME}.sh"
readonly UPDATER_DEST="/usr/local/sbin/${UPDATER_NAME}"

readonly OLD_CONF="${NGINX_CONF_DIR}/cloudflare-realip.conf"
readonly OLD_SERVICE='cloudflare-realip-nginx-update.service'
readonly OLD_TIMER='cloudflare-realip-nginx-update.timer'
readonly OLD_UPDATER='/usr/local/sbin/update-cloudflare-realip-nginx'

# Run
main() {
    require_root
    require_cmd chmod cp dirname install mkdir rm
    require_file "${UPDATER_SRC}"
    require_file "${SERVICE_SRC}"
    require_file "${TIMER_SRC}"
    require_file "${ACCESS_SRC}"

    local missing_packages=()
    command_exists curl || missing_packages+=(curl)
    command_exists python3 || missing_packages+=(python3)

    if ((${#missing_packages[@]} > 0)); then
        log_info "Installing Cloudflare updater dependencies: ${missing_packages[*]}..."
        apt-get update
        apt-get install -y --no-install-recommends "${missing_packages[@]}"
    fi

    log_info 'Installing Cloudflare NGINX updater...'
    install_file "${UPDATER_SRC}" "${UPDATER_DEST}" 755
    install -d -m 755 "${NGINX_CONF_DIR}"
    install -d -m 755 "$(dirname -- "${ACCESS_DEST}")"
    install_file "${ACCESS_SRC}" "${ACCESS_DEST}" 644
    install_file "${SERVICE_SRC}" "/etc/systemd/system/${SERVICE_NAME}" 644
    install_file "${TIMER_SRC}" "/etc/systemd/system/${TIMER_NAME}" 644

    if command_exists systemctl; then
        if [[ -f "/etc/systemd/system/${OLD_TIMER}" ]]; then
            systemctl disable --now "${OLD_TIMER}"
        fi

        if systemctl is-active --quiet "${OLD_SERVICE}"; then
            systemctl stop "${OLD_SERVICE}"
        fi
    fi

    rm -f "${OLD_CONF}" "/etc/systemd/system/${OLD_SERVICE}" "/etc/systemd/system/${OLD_TIMER}" "${OLD_UPDATER}"

    log_info 'Updating Cloudflare IP ranges for NGINX...'
    "${UPDATER_DEST}" --force-reload

    if command_exists systemctl; then
        systemctl daemon-reload
        systemctl enable --now "${TIMER_NAME}"
    else
        log_warn "systemctl is unavailable; timer installed but not enabled: ${TIMER_NAME}"
    fi

    log_success 'Cloudflare IP range auto-update configured for NGINX'
}

main "$@"
