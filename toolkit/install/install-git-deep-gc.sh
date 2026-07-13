#!/usr/bin/env bash
# Install the parallel recursive Git deep-GC helper.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

GIT_DEEP_GC_BIN="/usr/local/bin/git-deep-gc"
GIT_DEEP_GC_SRC="${REPO_ROOT}/toolkit/bin/git-deep-gc"

require_root
require_cmd basename chmod chown cp dirname find git mktemp nproc rm
require_file "${GIT_DEEP_GC_SRC}"

log_info "Installing git-deep-gc helper..."
rm -f -- "${GIT_DEEP_GC_BIN}"
cp -- "${GIT_DEEP_GC_SRC}" "${GIT_DEEP_GC_BIN}"
chown root:root "${GIT_DEEP_GC_BIN}"
chmod 755 "${GIT_DEEP_GC_BIN}"
log_success "git-deep-gc installed: ${GIT_DEEP_GC_BIN}"
