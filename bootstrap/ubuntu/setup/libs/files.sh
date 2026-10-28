#!/usr/bin/env bash

# shellcheck shell=bash

# Constants/Variables
readonly UBUNTU_FILES_DIR="${UBUNTU_BOOTSTRAP_DIR}/files"
readonly SETUP_FILES_MANIFEST="${UBUNTU_SETUP_DIR}/setup-files.txt"
readonly RECONFIGURE_FILES_MANIFEST="${UBUNTU_SETUP_DIR}/reconfigure-files.txt"

# Functions
validate_setup_files() {
    local mode path source_file
    local -A manifest_paths=()

    while read -r mode path; do
        manifest_paths["${path}"]="${mode}"
        if [[ ! -e "${UBUNTU_FILES_DIR}${path}" ]]; then
            log_error "Template path not found: ${path}"
            return 1
        fi
    done <"${SETUP_FILES_MANIFEST}"

    while IFS= read -r -d '' source_file; do
        path="/${source_file#"${UBUNTU_FILES_DIR}/"}"
        if [[ -z "${manifest_paths[${path}]:-}" ]]; then
            log_error "Template missing from setup manifest: ${path}"
            return 1
        fi
    done < <(find "${UBUNTU_FILES_DIR}" -type f -print0)
}

install_manifest_files() {
    local manifest="$1"
    local mode path

    while read -r mode path; do
        if [[ -d "${UBUNTU_FILES_DIR}${path}" ]]; then
            install -d -o root -g root -m "${mode}" "${path}"
        else
            install -D -o root -g root -m "${mode}" "${UBUNTU_FILES_DIR}${path}" "${path}"
        fi
    done <"${manifest}"
}

install_bootstrap_files() {
    log_info 'Installing bootstrap configuration and scripts...'
    install -d -m 755 /scripts
    install_manifest_files "${SETUP_FILES_MANIFEST}"
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
        done <"${SETUP_FILES_MANIFEST}"

        if [[ -d "${user_dir}/.ssh" ]]; then
            chmod 700 "${user_dir}/.ssh"
            find "${user_dir}/.ssh" -type f -exec chmod 600 {} +
        fi
    done

    log_success 'Home directories synchronized'
}

install_package_manager_configs() {
    local home_dir="$1"
    local template_dir="$2"
    local owner config

    if [[ -L "${home_dir}" || -L "${home_dir}/.config" || -L "${home_dir}/.config/pnpm" ]]; then
        log_warn "Skipping package-manager configuration for symlinked home or configuration directory: ${home_dir}"
        return 0
    fi

    owner="$(stat -c '%u:%g' "${home_dir}")"
    rm -f "${home_dir}/.config/pnpm/rc"

    if [[ ! -d "${home_dir}/.config" ]]; then
        install -d -o "${owner%:*}" -g "${owner#*:}" -m 700 "${home_dir}/.config"
    fi

    install -d -o "${owner%:*}" -g "${owner#*:}" -m 700 "${home_dir}/.config/pnpm"

    for config in .npmrc .bunfig.toml .config/pnpm/config.yaml; do
        install -o "${owner%:*}" -g "${owner#*:}" -m 600 "${template_dir}/${config}" "${home_dir}/${config}"
    done
}

reconfigure_bootstrap_files() {
    local home_dir template_dir

    log_info 'Reapplying managed configuration and scripts...'
    rm -f /etc/npmrc /etc/pnpm/rc /etc/bun/bunfig.toml /etc/skel/.config/pnpm/rc
    install_manifest_files "${RECONFIGURE_FILES_MANIFEST}"

    for home_dir in /root /home/*; do
        [[ -d "${home_dir}" ]] || continue
        [[ "${home_dir}" != /home/lost+found ]] || continue

        template_dir="${UBUNTU_FILES_DIR}/etc/skel"
        if [[ "${home_dir}" == /root ]]; then
            template_dir="${UBUNTU_FILES_DIR}/root"
        fi

        log_info "Installing package-manager configuration for: ${home_dir}..."
        install_package_manager_configs "${home_dir}" "${template_dir}"
    done

    log_success 'Managed configuration and scripts reapplied'
}
