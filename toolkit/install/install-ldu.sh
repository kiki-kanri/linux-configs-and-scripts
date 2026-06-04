#!/usr/bin/env bash
# Install the ldu disk-usage helper.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

LDU_BIN="/usr/local/bin/ldu"

require_root
require_cmd cat chmod column du sort

log_info "Installing ldu helper..."
cat >"${LDU_BIN}" <<'SCRIPT'
#!/bin/sh

if [ $# -eq 0 ]; then
    du -had1 . | sort -h | column -t
else
    du -had1 "$@" | sort -h | column -t
fi
SCRIPT

chmod 755 "${LDU_BIN}"
log_success "ldu installed: ${LDU_BIN}"
