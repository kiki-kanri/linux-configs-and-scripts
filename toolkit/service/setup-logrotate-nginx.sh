#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly LOGROTATE_SRC="${REPO_ROOT}/toolkit/conf/logrotate.d/nginx"
readonly LOGROTATE_DEST='/etc/logrotate.d/nginx'
readonly NGINX_LOG_DIR='/var/log/nginx'

# Run
main() {
    local validation_output

    require_root
    if [[ ! -x /usr/sbin/nginx ]]; then
        log_info 'Nginx is not installed; skipping logrotate setup'
        return 0
    fi

    if ! command_exists logrotate; then
        log_info 'Installing logrotate...'
        apt-get update
        apt-get install -y --no-install-recommends logrotate
    fi

    log_info "Installing NGINX logrotate policy: ${LOGROTATE_DEST}..."
    install -d -m 755 "${NGINX_LOG_DIR}"
    install -D -o root -g root -m 644 "${LOGROTATE_SRC}" "${LOGROTATE_DEST}"

    log_info 'Validating logrotate policy...'
    if ! validation_output="$(logrotate -d "${LOGROTATE_DEST}" 2>&1)"; then
        log_error "logrotate policy validation failed: ${LOGROTATE_DEST}"
        printf '%s\n' "${validation_output}" >&2
        return 1
    fi

    log_success 'NGINX logrotate policy installed'
}

main "$@"
