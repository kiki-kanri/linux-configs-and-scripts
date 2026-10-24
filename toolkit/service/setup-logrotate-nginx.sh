#!/usr/bin/env bash

# shellcheck disable=SC1091

# Install logrotate policy for nginx access and error logs.

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly LOGROTATE_SRC="${REPO_ROOT}/toolkit/conf/logrotate.d/nginx"
readonly LOGROTATE_DEST='/etc/logrotate.d/nginx'
readonly NGINX_LOG_DIR='/var/log/nginx'

# Functions
install_logrotate_if_missing() {
    command_exists logrotate && return 0

    log_info 'Installing logrotate...'
    apt-get update
    apt-get install -y --no-install-recommends logrotate
}

# Run
main() {
    require_root
    require_cmd install
    require_file "${LOGROTATE_SRC}"

    install_logrotate_if_missing

    log_info "Installing NGINX logrotate policy: ${LOGROTATE_DEST}..."
    install -d -m 755 "${NGINX_LOG_DIR}"
    install_file "${LOGROTATE_SRC}" "${LOGROTATE_DEST}" 644

    local validation_output
    log_info 'Validating logrotate policy...'
    if ! validation_output="$(logrotate -d "${LOGROTATE_DEST}" 2>&1)"; then
        log_error "logrotate policy validation failed: ${LOGROTATE_DEST}"
        printf '%s\n' "${validation_output}" >&2
        return 1
    fi

    log_success 'NGINX logrotate policy installed'
}

main "$@"
