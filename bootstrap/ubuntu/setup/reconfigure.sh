#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../../libs/common.sh"
readonly UBUNTU_BOOTSTRAP_DIR="${REPO_ROOT}/bootstrap/ubuntu"
readonly UBUNTU_SETUP_DIR="${UBUNTU_BOOTSTRAP_DIR}/setup"
source "${UBUNTU_SETUP_DIR}/libs/files.sh"
source "${UBUNTU_SETUP_DIR}/libs/tools.sh"

# Constants/Variables
readonly TOOLKIT_DIR="${REPO_ROOT}/toolkit"

# Run
main() {
    local ID VERSION_ID PRETTY_NAME

    require_root
    source /etc/os-release
    case "${ID}:${VERSION_ID}" in
    ubuntu:24.04 | ubuntu:26.04) ;;
    *)
        log_error "Unsupported release: ${PRETTY_NAME}"
        return 1
        ;;
    esac

    "${TOOLKIT_DIR}/install/install-base-packages.sh"
    reconfigure_bootstrap_files
    "${TOOLKIT_DIR}/init/disable-motds.sh"

    install_common_tools
    configure_system_tuning

    "${TOOLKIT_DIR}/security/setup-nginx-apparmor.sh"
    "${TOOLKIT_DIR}/service/setup-cloudflare-nginx.sh"
    "${TOOLKIT_DIR}/service/setup-logrotate-nginx.sh"
    "${TOOLKIT_DIR}/security/setup-fail2ban.sh"

    log_success 'Ubuntu reconfiguration complete'
}

main "$@"
