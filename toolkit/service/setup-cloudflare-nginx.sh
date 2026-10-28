#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly ACCESS_DEST='/etc/nginx/public/access/cloudflare-only.conf'
readonly ACCESS_SRC="${REPO_ROOT}/toolkit/conf/nginx/public/access/cloudflare-only.conf"
readonly SERVICE_NAME='cloudflare-nginx-update.service'
readonly SERVICE_SRC="${REPO_ROOT}/toolkit/conf/systemd/${SERVICE_NAME}"
readonly TIMER_NAME='cloudflare-nginx-update.timer'
readonly TIMER_SRC="${REPO_ROOT}/toolkit/conf/systemd/${TIMER_NAME}"
readonly UPDATER_NAME='update-cloudflare-nginx'
readonly UPDATER_SRC="${REPO_ROOT}/toolkit/service/${UPDATER_NAME}.sh"
readonly UPDATER_DEST="/usr/local/sbin/${UPDATER_NAME}"

readonly OLD_CONF='/etc/nginx/conf.d/cloudflare-realip.conf'
readonly OLD_SERVICE='cloudflare-realip-nginx-update.service'
readonly OLD_TIMER='cloudflare-realip-nginx-update.timer'
readonly OLD_UPDATER='/usr/local/sbin/update-cloudflare-realip-nginx'

# Run
main() {
    local -a missing_packages=()

    require_root
    if [[ ! -x /usr/sbin/nginx ]]; then
        log_info 'Nginx is not installed; skipping Cloudflare setup'
        return 0
    fi

    require_cmd systemctl

    command_exists curl || missing_packages+=(curl)
    command_exists python3 || missing_packages+=(python3)

    if ((${#missing_packages[@]} > 0)); then
        log_info "Installing Cloudflare updater dependencies: ${missing_packages[*]}..."
        apt-get update
        apt-get install -y --no-install-recommends "${missing_packages[@]}"
    fi

    log_info 'Installing Cloudflare NGINX updater...'
    install -D -o root -g root -m 755 "${UPDATER_SRC}" "${UPDATER_DEST}"
    install -D -o root -g root -m 644 "${ACCESS_SRC}" "${ACCESS_DEST}"
    install -D -o root -g root -m 644 "${SERVICE_SRC}" "/etc/systemd/system/${SERVICE_NAME}"
    install -D -o root -g root -m 644 "${TIMER_SRC}" "/etc/systemd/system/${TIMER_NAME}"

    if [[ -f "/etc/systemd/system/${OLD_TIMER}" ]]; then
        systemctl disable --now "${OLD_TIMER}"
    fi

    if systemctl is-active --quiet "${OLD_SERVICE}"; then
        systemctl stop "${OLD_SERVICE}"
    fi

    rm -f "${OLD_CONF}" "/etc/systemd/system/${OLD_SERVICE}" "/etc/systemd/system/${OLD_TIMER}" "${OLD_UPDATER}"

    log_info 'Updating Cloudflare IP ranges for NGINX...'
    "${UPDATER_DEST}" --force-reload

    systemctl daemon-reload
    systemctl enable --now "${TIMER_NAME}"

    log_success 'Cloudflare IP range auto-update configured for NGINX'
}

main "$@"
