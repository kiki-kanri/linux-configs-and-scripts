#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly SYSCTL_SRC="${REPO_ROOT}/toolkit/conf/sysctl.d/99-disable-ipv6.conf"
readonly SYSCTL_DEST='/etc/sysctl.d/99-disable-ipv6.conf'

# Run
main() {
    require_root
    if [[ "$(host_os)" != 'linux' ]]; then
        log_error 'IPv6 sysctl configuration requires Linux'
        exit 1
    fi

    require_cmd sysctl

    log_info 'Installing IPv6 disable configuration...'
    install -D -o root -g root -m 644 "${SYSCTL_SRC}" "${SYSCTL_DEST}"
    log_info 'Applying IPv6 disable configuration...'
    sysctl -p "${SYSCTL_DEST}"
    log_success 'IPv6 disable configuration applied'
}

main "$@"
