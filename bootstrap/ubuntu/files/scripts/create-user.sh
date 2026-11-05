#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/libs/common.sh"

# Functions
ask_yes_no() {
    local answer

    while true; do
        printf '%s (y/N): ' "$1" >&2
        if ! IFS= read -r answer; then
            log_error 'Input ended; cancelled'
            exit 1
        fi

        case "${answer}" in
        y | Y | yes | YES) return 0 ;;
        '' | n | N | no | NO) return 1 ;;
        *) log_error 'Please answer y or n' ;;
        esac
    done
}

name_available() {
    local new_user_name="$1"
    local database status path

    for database in passwd group; do
        if getent "${database}" "${new_user_name}" >/dev/null; then
            log_error "Name already exists in ${database}: ${new_user_name}"
            return 1
        else
            status=$?
            if ((status != 2)); then
                log_error "Failed to query ${database}; exit status: ${status}"
                exit 1
            fi
        fi
    done

    for path in "/home/${new_user_name}" "/etc/sudoers.d/${new_user_name}" "/etc/sudoers.d/90-${new_user_name}"; do
        if [[ -e "${path}" || -L "${path}" ]]; then
            log_error "Refusing to reuse existing path: ${path}"
            return 1
        fi
    done
}

finish() {
    local status=$?
    if [[ -n "${sudoers_temp}" ]]; then
        rm -f -- "${sudoers_temp}"
    fi

    if ((status != 0)); then
        log_error "Failed while ${step}; partial changes may remain; no account rollback was attempted"
    fi
}

# Run
main() (
    local new_user_name path
    local grant_sudo='no'
    local passwordless_sudo='no'
    local create_data='no'
    local own_nginx='no'
    local -a nginx_paths=()
    local step sudoers_temp=''

    require_root
    require_cmd getent addgroup adduser install touch chown chmod mkdir

    while true; do
        printf 'New username (1-32 characters; lowercase letter, then lowercase letters, digits, _ or -): ' >&2
        if ! IFS= read -r new_user_name; then
            log_error 'Input ended; cancelled'
            exit 1
        fi

        # Exclude dots so sudo will not ignore the matching sudoers.d filename.
        if [[ ! "${new_user_name}" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
            log_error 'Invalid username'
            continue
        fi

        if name_available "${new_user_name}"; then
            break
        fi
    done

    if ask_yes_no 'Grant sudo (root) privileges?'; then
        grant_sudo='yes'
        if ask_yes_no 'Allow passwordless sudo (NOPASSWD: ALL)?'; then
            passwordless_sudo='yes'
        else
            log_warn "The account will have no password; password-based sudo requires an administrator to run: passwd ${new_user_name}"
        fi
    fi

    if [[ ! -e /data && ! -L /data ]]; then
        if ask_yes_no 'Create /data and assign its ownership to the new user?'; then
            create_data='yes'
        fi
    else
        log_info '/data already exists; its ownership and permissions will not be changed'
    fi

    if [[ -d /etc/nginx ]]; then
        for path in /etc/nginx/domains /etc/nginx/public /etc/nginx/nginx.conf; do
            if [[ -e "${path}" || -L "${path}" ]]; then
                nginx_paths+=("${path}")
            else
                log_info "Skipping missing Nginx path: ${path}"
            fi
        done

        log_warn 'Ownership permits modifying Nginx configuration used by the server'
        if ask_yes_no 'Assign existing Nginx paths to the new user and set /etc/nginx to mode 755?'; then
            own_nginx='yes'
        fi
    fi

    log_info 'Creation summary'
    printf '  Username: %s\n  Home: /home/%s\n' "${new_user_name}" "${new_user_name}"
    printf '  Password: disabled; initialize .ssh (700) and authorized_keys (600), preserving any skeleton keys\n'
    printf '  Sudo: %s\n  Passwordless sudo: %s\n  Create and own /data (755): %s\n  Own Nginx paths: %s\n' \
        "${grant_sudo}" "${passwordless_sudo}" "${create_data}" "${own_nginx}"
    if [[ "${own_nginx}" == yes ]]; then
        printf '  /etc/nginx mode: 755\n'
        for path in "${nginx_paths[@]}"; do
            printf '  Nginx ownership: %s\n' "${path}"
        done
    fi

    if ! ask_yes_no 'Confirm creation?'; then
        log_info 'Cancelled; no changes made'
        return 0
    fi

    # Recheck after confirmation; another administrator may have changed the system.
    name_available "${new_user_name}" || return 1
    if [[ "${create_data}" == yes && (-e /data || -L /data) ]]; then
        log_error '/data appeared after prompting; aborting without changes'
        exit 1
    fi

    if [[ "${own_nginx}" == yes ]]; then
        if [[ ! -d /etc/nginx || -L /etc/nginx ]]; then
            log_error '/etc/nginx is missing or a symlink; aborting without changes'
            exit 1
        fi

        for path in "${nginx_paths[@]}"; do
            if [[ ! -e "${path}" || -L "${path}" ]]; then
                log_error "Nginx path is missing or a symlink; aborting without changes: ${path}"
                exit 1
            fi
        done
    fi

    if [[ "${grant_sudo}" == yes ]]; then
        require_cmd usermod visudo
        getent group sudo >/dev/null
        visudo -c
    fi

    if [[ "${passwordless_sudo}" == yes ]]; then
        require_cmd mktemp ln rm
        if [[ ! -d /etc/sudoers.d || -L /etc/sudoers.d ]]; then
            log_error '/etc/sudoers.d must be an existing, non-symlink directory'
            exit 1
        fi
    fi

    step='creating the user group'
    trap finish EXIT

    # Explicit home and group avoid depending on local adduser.conf defaults.
    log_info "Creating the user group: ${new_user_name}..."
    addgroup "${new_user_name}"
    step='creating the account'
    log_info "Creating the account: ${new_user_name}..."
    adduser --disabled-password --comment '' --home "/home/${new_user_name}" --ingroup "${new_user_name}" "${new_user_name}"

    step='initializing SSH files'
    log_info 'Initializing SSH files...'
    if [[ -L "/home/${new_user_name}" || -L "/home/${new_user_name}/.ssh" || -L "/home/${new_user_name}/.ssh/authorized_keys" ]]; then
        log_error 'Refusing to initialize symlinked home or SSH paths'
        exit 1
    fi

    install -d -m 700 -o "${new_user_name}" -g "${new_user_name}" "/home/${new_user_name}/.ssh"
    touch "/home/${new_user_name}/.ssh/authorized_keys"
    chown -hR -- "${new_user_name}:${new_user_name}" "/home/${new_user_name}/.ssh"
    chmod 600 "/home/${new_user_name}/.ssh/authorized_keys"

    if [[ "${grant_sudo}" == yes ]]; then
        step='granting sudo privileges'
        log_info 'Granting sudo privileges...'
        usermod -aG sudo "${new_user_name}"
        if [[ "${passwordless_sudo}" == yes ]]; then
            sudoers_temp="$(mktemp /etc/sudoers.d/.create-user.XXXXXX)"
            printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "${new_user_name}" >"${sudoers_temp}"
            chown root:root "${sudoers_temp}"
            chmod 440 "${sudoers_temp}"
            visudo -cf "${sudoers_temp}"
            # Publish only after validation, without overwriting an existing entry.
            ln -T -- "${sudoers_temp}" "/etc/sudoers.d/${new_user_name}"
        fi

        visudo -c
    fi

    if [[ "${create_data}" == yes ]]; then
        step='creating /data'
        log_info 'Creating /data...'
        # mkdir must fail if /data appeared; never chown an existing path.
        mkdir -m 755 /data
        chown -- "${new_user_name}:${new_user_name}" /data
    fi

    if [[ "${own_nginx}" == yes ]]; then
        step='assigning Nginx ownership'
        log_info 'Assigning Nginx ownership...'
        chmod 755 /etc/nginx
        for path in "${nginx_paths[@]}"; do
            chown -hR -- "${new_user_name}:${new_user_name}" "${path}"
        done
    fi

    log_success "Created user: ${new_user_name}"
    log_info "Add an SSH public key before SSH login: /home/${new_user_name}/.ssh/authorized_keys"
    if [[ "${grant_sudo}" == yes && "${passwordless_sudo}" == no ]]; then
        log_warn "Password-based sudo requires an administrator to run: passwd ${new_user_name}"
    fi
)

main "$@"
