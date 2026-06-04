#!/usr/bin/env bash
# Install database-friendly THP and memory-overcommit tuning.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

UNIT_NAME="thp-tuning.service"
UNIT_SRC="${REPO_ROOT}/toolkit/conf/systemd/${UNIT_NAME}"
UNIT_DEST="/etc/systemd/system/${UNIT_NAME}"
SYSCTL_SRC="${REPO_ROOT}/toolkit/conf/sysctl.d/99-db-tuning.conf"
SYSCTL_DEST="/etc/sysctl.d/99-db-tuning.conf"
THP_PATH="/sys/kernel/mm/transparent_hugepage"

write_runtime_value() {
    local path="$1"
    local value="$2"
    local label="$3"

    if [[ ! -e "${path}" ]]; then
        log_warn "Skipping ${label}; ${path} does not exist."
        return 0
    fi

    if echo "${value}" >"${path}" 2>/dev/null; then
        log_info "${label}: ${value}"
    else
        log_warn "Could not set ${label} via ${path}."
    fi
}

apply_runtime_settings() {
    log_info "Applying runtime THP tuning..."
    write_runtime_value "${THP_PATH}/enabled" "madvise" "THP enabled"
    write_runtime_value "${THP_PATH}/defrag" "madvise" "THP defrag"
    write_runtime_value "${THP_PATH}/khugepaged/max_ptes_none" "0" "khugepaged max_ptes_none"

    log_info "Applying runtime sysctl tuning..."
    sysctl --system >/dev/null
    log_info "vm.overcommit_memory: $(sysctl -n vm.overcommit_memory)"
}

install_persistent_settings() {
    require_file "${UNIT_SRC}"
    require_file "${SYSCTL_SRC}"

    log_info "Installing sysctl config: ${SYSCTL_DEST}"
    install_file "${SYSCTL_SRC}" "${SYSCTL_DEST}" 644

    if ! command_exists systemctl; then
        log_warn "systemctl not found; THP runtime settings were applied but boot persistence was not installed."
        return 0
    fi

    log_info "Installing systemd unit: ${UNIT_DEST}"
    install_file "${UNIT_SRC}" "${UNIT_DEST}" 644
    systemctl daemon-reload
    systemctl enable "${UNIT_NAME}"
    systemctl restart "${UNIT_NAME}"
    log_success "Boot persistence enabled: ${UNIT_NAME}"
}

if (($# > 0)); then
    log_error "Unexpected argument: $1"
    exit 1
fi

require_root
require_cmd sysctl

install_persistent_settings
apply_runtime_settings
log_success "THP tuning setup complete."
