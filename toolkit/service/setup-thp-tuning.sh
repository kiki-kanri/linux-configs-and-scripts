#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# setup-thp-tuning.sh — Configure Transparent Huge Pages (THP) for database workloads
#
# Sets THP to "madvise" mode and installs a systemd oneshot service for boot persistence.
# Applies immediately (no reboot required).

set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root

UNIT_NAME="thp-tuning"
UNIT_PATH="/etc/systemd/system/${UNIT_NAME}.service"
SYS_PATH="/sys/kernel/mm/transparent_hugepage"
PROC_PATH="/proc/sys/vm"
SRC="${SCRIPT_DIR}/../conf/systemd/thp-tuning.service"

# ── apply runtime settings ────────────────────────────────────────────────────
log_info "Applying THP settings (runtime)..."
echo madvise >"${SYS_PATH}/enabled" 2>/dev/null || true
echo madvise >"${SYS_PATH}/defrag" 2>/dev/null || true
echo 0 >"${SYS_PATH}/khugepaged/max_ptes_none" 2>/dev/null || true
echo 1 >"${PROC_PATH}/overcommit_memory" 2>/dev/null || true
log_success "THP settings applied (runtime)."

# ── install systemd unit ──────────────────────────────────────────────────────
if [[ ! -f "${SRC}" ]]; then
    log_error "Service template not found: ${SRC}"
    exit 1
fi

log_info "Installing systemd unit..."
cp -f "${SRC}" "${UNIT_PATH}"
systemctl daemon-reload
systemctl enable "${UNIT_NAME}"
systemctl start "${UNIT_NAME}"
log_success "THP tuning enabled (runtime + boot-persistent)."
