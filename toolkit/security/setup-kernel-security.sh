#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly SYSCTL_SRC="${REPO_ROOT}/toolkit/conf/sysctl.d/99-zz-kernel-security.conf"
readonly SYSCTL_DEST='/etc/sysctl.d/99-zz-kernel-security.conf'

# Run
main() {
    require_root
    if [[ "$(host_os)" != 'linux' ]]; then
        log_error 'Kernel security baseline requires Linux'
        exit 1
    fi

    # Fail before changing the persistent configuration if runtime application is unavailable.
    require_cmd sysctl

    log_info "Installing kernel security baseline: ${SYSCTL_DEST}..."
    install -D -o root -g root -m 644 "${SYSCTL_SRC}" "${SYSCTL_DEST}"

    # Apply only this file; do not replay unrelated tuning or ignore rejected settings.
    log_info 'Applying kernel security baseline...'
    sysctl -p "${SYSCTL_DEST}"

    log_success 'Kernel security baseline installed and applied'
}

main "$@"
