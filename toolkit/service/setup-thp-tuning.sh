#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly UNIT_NAME='thp-tuning.service'
readonly UNIT_SRC="${REPO_ROOT}/toolkit/conf/systemd/${UNIT_NAME}"
readonly SYSCTL_SRC="${REPO_ROOT}/toolkit/conf/sysctl.d/99-db-tuning.conf"
readonly SYSCTL_DEST='/etc/sysctl.d/99-db-tuning.conf'

# Run
main() {
    require_root
    if [[ "$(host_os)" != 'linux' ]]; then
        log_error 'THP tuning requires Linux'
        exit 1
    fi

    require_cmd sysctl systemctl

    log_info 'Installing THP and memory tuning configuration...'
    install -D -o root -g root -m 644 "${SYSCTL_SRC}" "${SYSCTL_DEST}"
    install -D -o root -g root -m 644 "${UNIT_SRC}" "/etc/systemd/system/${UNIT_NAME}"

    log_info 'Applying memory tuning...'
    sysctl -p "${SYSCTL_DEST}"
    log_info 'Enabling and applying THP tuning...'
    systemctl daemon-reload
    systemctl enable "${UNIT_NAME}"
    # Reapply even when the oneshot service is already active.
    systemctl restart "${UNIT_NAME}"
    log_success 'THP and memory tuning applied with boot persistence'
}

main "$@"
