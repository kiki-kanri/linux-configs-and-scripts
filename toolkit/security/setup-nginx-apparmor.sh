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

# Run
main() {
    local mode='complain'

    require_root
    if [[ "$(host_os)" != 'linux' ]] || ! command_exists apparmor_parser || [[ ! -r "${LOADED_PROFILES}" ]]; then
        log_info 'AppArmor is unavailable or not enabled; skipping Nginx profile setup'
        return 0
    fi

    if [[ -e /etc/apparmor.d/disable/usr.sbin.nginx || -L /etc/apparmor.d/disable/usr.sbin.nginx ]]; then
        log_info 'Nginx AppArmor profile is explicitly disabled; skipping setup'
        return 0
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
    log_success 'Nginx AppArmor profile loaded; restart Nginx to attach previously unconfined processes'
}

main "$@"
