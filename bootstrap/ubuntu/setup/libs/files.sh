#!/usr/bin/env bash

# shellcheck shell=bash

# Constants/Variables
readonly UBUNTU_FILES_DIR="${UBUNTU_BOOTSTRAP_DIR}/files"
readonly BOOTSTRAP_PERMISSIONS="${UBUNTU_SETUP_DIR}/files-permissions.txt"

# Functions
validate_bootstrap_permissions() {
    local mode path source_file
    local -A configured_paths=()

    while read -r mode path; do
        configured_paths["${path}"]="${mode}"
        if [[ ! -e "${UBUNTU_FILES_DIR}${path}" ]]; then
            log_error "Permission path not found in bootstrap files: ${path}"
            return 1
        fi
    done <"${BOOTSTRAP_PERMISSIONS}"

    while IFS= read -r -d '' source_file; do
        path="/${source_file#"${UBUNTU_FILES_DIR}/"}"
        if [[ -z "${configured_paths[${path}]:-}" ]]; then
            log_error "Permission not configured for bootstrap file: ${path}"
            return 1
        fi
    done < <(find "${UBUNTU_FILES_DIR}" -type f -print0)
}

rsync_bootstrap_dir() {
    local dest="$1"
    local old_mode

    old_mode="$(stat -c '%a' "${dest}")"
    rsync -a "${UBUNTU_FILES_DIR}${dest}" "${dest}"
    chmod "${old_mode}" "${dest}"
}

install_bootstrap_files() {
    local mode path

    log_info 'Installing bootstrap configuration and scripts...'
    install -d -m 755 /scripts
    rsync_bootstrap_dir /etc/
    rsync_bootstrap_dir /root/
    rsync_bootstrap_dir /scripts/

    while read -r mode path; do
        chown root:root "${path}"
        chmod "${mode}" "${path}"
    done <"${BOOTSTRAP_PERMISSIONS}"
}

sync_bootstrap_home_dirs() {
    local user_dir user_name mode path

    log_info 'Syncing /etc/skel to existing home directories...'
    for user_dir in /home/*; do
        [[ -d "${user_dir}" ]] || continue
        [[ "$(basename -- "${user_dir}")" != 'lost+found' ]] || continue

        user_name="$(basename -- "${user_dir}")"
        rsync -a /etc/skel/ "${user_dir}/"
        chown -R "${user_name}:${user_name}" "${user_dir}"

        while read -r mode path; do
            case "${path}" in
            /etc/skel/*) chmod "${mode}" "${user_dir}/${path#/etc/skel/}" ;;
            esac
        done <"${BOOTSTRAP_PERMISSIONS}"

        if [[ -d "${user_dir}/.ssh" ]]; then
            chmod 700 "${user_dir}/.ssh"
            find "${user_dir}/.ssh" -type f -exec chmod 600 {} +
        fi
    done

    log_success 'Home directories synchronized'
}
