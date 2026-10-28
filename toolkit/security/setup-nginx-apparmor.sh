#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly PROFILE_SRC="${REPO_ROOT}/toolkit/conf/apparmor.d/usr.sbin.nginx"
readonly PROFILE_DEST='/etc/apparmor.d/usr.sbin.nginx'
readonly LOCAL_PROFILE='/etc/apparmor.d/local/usr.sbin.nginx'
readonly LOADED_PROFILES='/sys/kernel/security/apparmor/profiles'

# Functions
verify_nginx_profile() {
    local master_pid worker_pids pid label

    if ! grep -q '^nginx (' "${LOADED_PROFILES}"; then
        log_info 'Nginx AppArmor profile is not loaded; skipping verification'
        return 0
    fi

    master_pid="$(systemctl show -p MainPID --value nginx.service)"
    worker_pids="$(cat "/proc/${master_pid}/task/${master_pid}/children")"
    for pid in "${master_pid}" ${worker_pids}; do
        label="$(cat "/proc/${pid}/attr/current")"
        case "${label}" in
        'nginx (complain)' | 'nginx (enforce)') log_info "Nginx AppArmor label for PID ${pid}: ${label}" ;;
        *)
            log_error "Nginx process is not using the expected AppArmor profile: PID ${pid}; ${label}"
            return 1
            ;;
        esac
    done
}

# Run
main() {
    local mode='complain'
    local action='setup'

    while (($# > 0)); do
        case "$1" in
        --verify) action='verify' ;;
        --load-only) action='load' ;;
        *)
            log_error "Unknown argument: $1"
            return 2
            ;;
        esac

        shift
    done

    require_root
    if [[ ! -x /usr/sbin/nginx ]]; then
        log_info 'Nginx is not installed; skipping AppArmor setup'
        return 0
    fi

    if [[ "$(host_os)" != 'linux' ]] || ! command_exists apparmor_parser || [[ ! -r "${LOADED_PROFILES}" ]]; then
        log_info 'AppArmor is unavailable or not enabled; skipping Nginx profile setup'
        return 0
    fi

    if [[ -e /etc/apparmor.d/disable/usr.sbin.nginx || -L /etc/apparmor.d/disable/usr.sbin.nginx ]]; then
        log_info 'Nginx AppArmor profile is explicitly disabled; skipping setup'
        return 0
    fi

    if [[ "${action}" == 'verify' ]]; then
        verify_nginx_profile
        return
    fi

    # aa-enforce removes the complain flag; preserve the administrator's persistent mode.
    if [[ -f "${PROFILE_DEST}" ]] && ! grep -Eq 'flags[[:space:]]*=[[:space:]]*\([^)]*complain' "${PROFILE_DEST}"; then
        mode='enforce'
    fi

    log_info "Installing Nginx AppArmor baseline in ${mode} mode..."
    install -d -m 755 /etc/apparmor.d/local
    if [[ ! -e "${LOCAL_PROFILE}" ]]; then
        install -o root -g root -m 644 /dev/null "${LOCAL_PROFILE}"
    fi

    install -o root -g root -m 644 "${PROFILE_SRC}" "${PROFILE_DEST}"
    if [[ "${mode}" == 'enforce' ]]; then
        sed -i 's/flags=(complain)/flags=(enforce)/' "${PROFILE_DEST}"
    fi

    apparmor_parser -r "${PROFILE_DEST}"
    if [[ "${action}" == 'load' ]]; then
        log_success 'Nginx AppArmor profile loaded'
        return 0
    fi

    log_info 'Validating and restarting Nginx with AppArmor...'
    /usr/sbin/nginx -t
    systemctl restart nginx.service
    verify_nginx_profile
    log_success 'Nginx restarted and AppArmor profile verified'
}

main "$@"
