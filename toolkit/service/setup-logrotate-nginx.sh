#!/usr/bin/env bash
# Install logrotate policy for nginx access and error logs.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

LOGROTATE_SRC="${REPO_ROOT}/toolkit/conf/logrotate.d/nginx"
LOGROTATE_DEST="/etc/logrotate.d/nginx"
NGINX_LOG_DIR="/var/log/nginx"

install_logrotate_if_missing() {
    command_exists logrotate && return 0

    require_cmd apt-get
    log_info "Installing logrotate..."
    apt-get update
    apt-get install -y --no-install-recommends logrotate
}

if (($# > 0)); then
    log_error "Unexpected argument: $1"
    exit 1
fi

require_root
require_cmd install
require_file "${LOGROTATE_SRC}"

install_logrotate_if_missing

log_info "Installing nginx logrotate policy: ${LOGROTATE_DEST}"
install -d -m 755 "${NGINX_LOG_DIR}"
install_file "${LOGROTATE_SRC}" "${LOGROTATE_DEST}" 644

if command_exists logrotate; then
    log_info "Validating logrotate policy..."
    logrotate -d "${LOGROTATE_DEST}" >/dev/null
fi

log_success "nginx logrotate policy installed."
