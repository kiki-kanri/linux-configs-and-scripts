#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# Disable IPv6 using the repository sysctl template.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

SYSCTL_SRC="${SCRIPT_DIR}/../conf/sysctl.d/99-disable-ipv6.conf"
SYSCTL_DEST="/etc/sysctl.d/99-disable-ipv6.conf"

require_root
require_cmd sysctl

log_info "Installing IPv6 disable sysctl config..."
install_file "${SYSCTL_SRC}" "${SYSCTL_DEST}" 644

log_info "Applying sysctl config: ${SYSCTL_DEST}"
sysctl -p "${SYSCTL_DEST}" >/dev/null

log_success "IPv6 sysctl config installed and applied."
