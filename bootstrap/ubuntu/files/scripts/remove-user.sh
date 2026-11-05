#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/libs/common.sh"

# Run
main() {
    local user_name passwd_entry account_name target_uid _

    if [[ $# -ne 1 ]]; then
        log_error "Usage: sudo bash $0 USERNAME"
        return 1
    fi

    user_name="$1"

    # Require a literal username, never a UID, option, or path component.
    if [[ ! "${user_name}" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*[$]?$ ]]; then
        log_error "Invalid username: ${user_name}"
        return 1
    fi

    require_root
    require_cmd getent loginctl deluser rm groupdel visudo

    # Only local accounts can be removed by deluser; do not resolve LDAP/NIS users.
    if ! passwd_entry="$(getent --service=files passwd "${user_name}")"; then
        log_error "Local user not found: ${user_name}"
        return 1
    fi

    IFS=: read -r account_name _ target_uid _ <<<"${passwd_entry}"
    if [[ "${account_name}" != "${user_name}" || ! "${target_uid}" =~ ^[0-9]{1,10}$ ]]; then
        log_error "Invalid local passwd entry for: ${user_name}"
        return 1
    fi

    if ((10#${target_uid} < 1000)); then
        log_error "Refusing to delete ${user_name}; UID is below 1000: ${target_uid}"
        return 1
    fi

    if [[ "${target_uid}" == "${SUDO_UID:-${EUID}}" ]]; then
        log_error 'Refusing to delete the invoking user; use another administrator account'
        return 1
    fi

    visudo -c

    log_warn "Removing the account and all owned files, including outside /home: ${user_name}"
    log_info "Cleaning up user sessions: ${user_name}..."
    # logind may have no user state; session/linger cleanup is best-effort.
    # Disable lingering first so the user manager will not be kept after logout.
    loginctl disable-linger "${user_name}" 2>/dev/null || true
    loginctl terminate-user "${user_name}" 2>/dev/null || true

    # Do not continue cleanup if account/file removal fails (e.g. remaining processes).
    log_info "Removing the account and owned files: ${user_name}..."
    deluser --remove-all-files "${user_name}"

    log_info "Removing residual user paths: ${user_name}..."
    rm -rf -- \
        "/home/${user_name:?}" \
        "/var/mail/${user_name}" \
        "/var/spool/mail/${user_name}" \
        "/var/spool/cron/crontabs/${user_name}" \
        "/etc/sudoers.d/${user_name}" \
        "/etc/sudoers.d/90-${user_name}" \
        "/var/lib/systemd/linger/${user_name}"

    # deluser may already have removed the private group; never force group removal.
    if getent --service=files group "${user_name}" >/dev/null; then
        log_info "Removing the user group: ${user_name}..."
        groupdel "${user_name}"
    fi

    visudo -c
    log_success "Removed user: ${user_name}"
}

main "$@"
