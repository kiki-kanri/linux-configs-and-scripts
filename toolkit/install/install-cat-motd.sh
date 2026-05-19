#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# Install the custom cat MOTD script.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

MOTD_SRC="${SCRIPT_DIR}/../conf/update-motd.d/9999-cat"
MOTD_DEST="/etc/update-motd.d/9999-cat"

require_root
require_dir /etc/update-motd.d

log_info "Installing cat MOTD script..."
install_file "${MOTD_SRC}" "${MOTD_DEST}" 755

log_success "Cat MOTD installed: ${MOTD_DEST}"
