#!/usr/bin/env bash

# shellcheck shell=bash

# Constants/Variables
readonly SCRIPTS_REPO_DIR='/scripts/linux-configs-and-scripts'

# Functions
install_common_tools() {
    "${TOOLKIT_DIR}/install/install-git-deep-gc.sh"
    "${TOOLKIT_DIR}/install/install-ldu.sh"
    "${TOOLKIT_DIR}/install/install-7zip.sh"
    "${TOOLKIT_DIR}/install/install-cat-motd.sh"

    # A formatter is optional; its download failure must not abort provisioning.
    log_info 'Installing optional shfmt...'
    "${TOOLKIT_DIR}/install/install-shfmt.sh" || log_warn 'Optional shfmt installation failed; continuing'
}

configure_system_tuning() {
    "${TOOLKIT_DIR}/service/setup-thp-tuning.sh"
    "${TOOLKIT_DIR}/security/setup-kernel-security.sh"
}

install_scripts_repository() {
    local commit

    log_info "Cloning linux-configs-and-scripts to: ${SCRIPTS_REPO_DIR}..."
    install -d -m 755 /scripts
    rm -rf "${SCRIPTS_REPO_DIR}"
    git clone "${REPO_URL}" "${SCRIPTS_REPO_DIR}"
    commit="$(git -C "${SCRIPTS_REPO_DIR}" rev-parse HEAD)"
    log_info "Installed repository commit: ${commit}"
    "${SCRIPTS_REPO_DIR}/modify-files-permissions.sh"
}
