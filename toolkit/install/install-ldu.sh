#!/usr/bin/env bash
# Install the ldu disk-usage helper.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

LDU_BIN="/usr/local/bin/ldu"
LDU_SRC="${REPO_ROOT}/toolkit/bin/ldu"

require_root
require_cmd chmod chown column cp du rm sort
require_file "${LDU_SRC}"

log_info "Installing ldu helper..."
rm -f -- "${LDU_BIN}"
cp -- "${LDU_SRC}" "${LDU_BIN}"
chown root:root "${LDU_BIN}"
chmod 755 "${LDU_BIN}"
log_success "ldu installed: ${LDU_BIN}"
