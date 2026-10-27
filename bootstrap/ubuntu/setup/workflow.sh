#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

readonly UBUNTU_BOOTSTRAP_DIR="${REPO_ROOT}/bootstrap/ubuntu"
readonly UBUNTU_SETUP_DIR="${UBUNTU_BOOTSTRAP_DIR}/setup"
source "${UBUNTU_SETUP_DIR}/libs/files.sh"
source "${UBUNTU_SETUP_DIR}/libs/access.sh"
source "${UBUNTU_SETUP_DIR}/libs/system.sh"
source "${UBUNTU_SETUP_DIR}/libs/tools.sh"

# Constants/Variables
readonly TOOLKIT_DIR="${REPO_ROOT}/toolkit"

# Functions
setup_ubuntu() {
    local ssh_port timezone

    require_root
    validate_bootstrap_permissions
    "${TOOLKIT_DIR}/install/install-base-packages.sh" --initial-setup
    require_cmd chmod chown find install locale-gen rsync sed stat systemctl ufw update-locale

    ssh_port="$(read_ssh_port)"
    log_info "Selected SSH port: ${ssh_port}"
    timezone="$(read_timezone)"
    log_info "Selected timezone: ${timezone}"

    install_bootstrap_files
    configure_bootstrap_access "${ssh_port}"
    sync_bootstrap_home_dirs
    configure_bootstrap_system "${timezone}"
    install_bootstrap_tools
    configure_bootstrap_tuning
    install_scripts_repository

    log_success 'Bootstrap complete; reboot is recommended'
}
