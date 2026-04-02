#!/bin/bash
# install-cat-motd.sh — Install the cat MOTD banner script

set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root

SRC="${SCRIPT_DIR}/../conf/update-motd.d/9999-cat"
DEST="/etc/update-motd.d/9999-cat"

if [[ ! -f "${SRC}" ]]; then
    log_error "Source file not found: ${SRC}"
    exit 1
fi

log_info "Installing cat MOTD script..."
cp -f "${SRC}" "${DEST}"
chmod 755 "${DEST}"
log_success "Installed: ${DEST}"
