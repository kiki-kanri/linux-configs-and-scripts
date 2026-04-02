#!/bin/bash
# disable-ipv6.sh — Disable IPv6 on the system

set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root

SRC="${SCRIPT_DIR}/../conf/sysctl.d/99-disable-ipv6.conf"
SYSCTL_CONF="/etc/sysctl.d/99-disable-ipv6.conf"

if [[ ! -f "${SRC}" ]]; then
    log_error "sysctl template not found: ${SRC}"
    exit 1
fi

log_info "Disabling IPv6..."
cp -f "${SRC}" "${SYSCTL_CONF}"
sysctl -p "${SYSCTL_CONF}" >/dev/null 2>&1 || true
log_success "IPv6 disabled."
