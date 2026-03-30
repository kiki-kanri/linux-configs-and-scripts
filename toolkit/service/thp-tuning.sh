#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# thp-tuning.sh — Configure Transparent Huge Pages (THP) for database workloads
#
# Disables THP defrag and sets it to "madvise" mode, which is recommended
# for MongoDB, Redis, MySQL, and other databases that manage memory heavily.
#
# Installs a systemd oneshot service that runs at boot.
# Does NOT require a reboot — applies immediately.
#
# Usage:
#   thp-tuning.sh --enable    # install and apply now
#   thp-tuning.sh --disable   # remove the systemd unit and restore defaults
#   thp-tuning.sh             # interactive

set -Eeuo pipefail

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

is_applied() {
    [[ "$(cat "${SYS_PATH}/enabled" 2>/dev/null)" == *"madvise"* ]]
}

apply_now() {
    log_info "Applying THP settings (runtime)..."
    # madvise: THP exists but only used when apps explicitly request it.
    # MongoDB 8 and other databases call madvise(MADV_HUGEPAGE) themselves.
    echo madvise >"${SYS_PATH}/enabled" 2>/dev/null || true
    echo madvise >"${SYS_PATH}/defrag" 2>/dev/null || true
    # Reduce khugepaged memory pressure
    echo 0 >"${SYS_PATH}/khugepaged/max_ptes_none" 2>/dev/null || true
    # VM overcommit — required by Redis, MongoDB, etc.
    echo 1 >"${PROC_PATH}/overcommit_memory" 2>/dev/null || true
    log_success "THP settings applied (runtime)."
}

install_unit() {
    local src="${SCRIPT_DIR}/../conf/systemd/thp-tuning.service"

    if [[ ! -f "${src}" ]]; then
        log_error "Service template not found: ${src}"
        exit 1
    fi

    log_info "Installing systemd unit from ${src}..."
    cp -f "${src}" "${UNIT_PATH}"
    systemctl daemon-reload
    systemctl enable "${UNIT_NAME}"
    systemctl start "${UNIT_NAME}"
    log_success "Systemd unit installed and enabled."
}

remove_unit() {
    log_info "Removing ${UNIT_NAME} systemd unit..."
    systemctl stop "${UNIT_NAME}" 2>/dev/null || true
    systemctl disable "${UNIT_NAME}" 2>/dev/null || true
    rm -f "${UNIT_PATH}"
    systemctl daemon-reload
    log_success "Removed. System reverts to default THP on next reboot."
}

show_status() {
    echo "=== THP Status ==="
    echo "enabled  : $(cat "${SYS_PATH}/enabled" 2>/dev/null || echo 'N/A')"
    echo "defrag   : $(cat "${SYS_PATH}/defrag" 2>/dev/null || echo 'N/A')"
    echo "max_ptes : $(cat "${SYS_PATH}/khugepaged/max_ptes_none" 2>/dev/null || echo 'N/A')"
    echo "overcommit: $(cat "${PROC_PATH}/overcommit_memory" 2>/dev/null || echo 'N/A')"
    echo
    if systemctl is-enabled "${UNIT_NAME}" &>/dev/null; then
        echo "Systemd unit: ${UNIT_NAME} — ENABLED (boot-persistent)"
    else
        echo "Systemd unit: ${UNIT_NAME} — NOT installed"
    fi
}

main() {
    local action=""

    if [[ $# -eq 0 ]]; then
        show_status
        echo
        if systemctl is-enabled "${UNIT_NAME}" &>/dev/null; then
            log_info "THP tuning is currently ENABLED."
            confirm "Disable THP tuning?" --default=no && action="disable" || exit 0
        else
            log_info "THP tuning is currently DISABLED."
            confirm "Enable THP tuning?" --default=yes && action="enable" || exit 0
        fi
    else
        case "$1" in
        --enable | -e) action="enable" ;;
        --disable | -d) action="disable" ;;
        --status | -s)
            show_status
            exit 0
            ;;
        --help | -h)
            echo "Usage: $0 {--enable|--disable|--status}"
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
        esac
    fi

    case "${action}" in
    enable)
        apply_now
        install_unit
        log_success "THP tuning enabled (runtime + boot-persistent)."
        ;;
    disable)
        remove_unit
        log_info "Runtime settings still in effect until reboot."
        ;;
    esac
}

main "$@"
