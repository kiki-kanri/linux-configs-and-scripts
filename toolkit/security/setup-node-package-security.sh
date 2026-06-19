#!/usr/bin/env bash
# Apply npm, pnpm and bun security defaults to system, skel, root and existing users.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

# Constants
NPMRC_SRC="${REPO_ROOT}/bootstrap/ubuntu/files/etc/npmrc"
PNPMRC_SRC="${REPO_ROOT}/bootstrap/ubuntu/files/etc/pnpm/rc"
BUNFIG_SRC="${REPO_ROOT}/bootstrap/ubuntu/files/etc/bun/bunfig.toml"
NODE_PROFILE_SRC="${REPO_ROOT}/bootstrap/ubuntu/files/etc/profile.d/99-node-security.sh"
UMASK_PROFILE_SRC="${REPO_ROOT}/bootstrap/ubuntu/files/etc/profile.d/99-security-umask.sh"

# Functions
apply_npm_config_if_available() {
    if ! command_exists npm; then
        log_warn "npm not found; npm config set commands skipped."
        return 0
    fi

    log_info "Applying global npm config..."
    npm config set min-release-age 1 -g
    npm config set ignore-scripts true -g
    npm config set engine-strict false -g
    npm config set audit true -g
    npm config set fund false -g
    npm config set update-notifier false -g
    npm config set strict-ssl true -g
    npm config set package-lock true -g
    npm config set prefer-online true -g
    npm config set prefer-offline false -g
    npm config set legacy-peer-deps false -g
}

copy_user_configs() {
    local home_dir="$1"
    local owner_group="$2"

    install -d -m 700 "${home_dir}/.config/pnpm"
    install_file "${NPMRC_SRC}" "${home_dir}/.npmrc" 600
    install_file "${PNPMRC_SRC}" "${home_dir}/.config/pnpm/rc" 600
    install_file "${BUNFIG_SRC}" "${home_dir}/.bunfig.toml" 600
    chown "${owner_group}" "${home_dir}/.npmrc" "${home_dir}/.bunfig.toml"
    chown -R "${owner_group}" "${home_dir}/.config/pnpm"
}

# Run
require_root
require_cmd basename chmod chown install stat
require_file "${NPMRC_SRC}"
require_file "${PNPMRC_SRC}"
require_file "${BUNFIG_SRC}"
require_file "${NODE_PROFILE_SRC}"
require_file "${UMASK_PROFILE_SRC}"

log_info "Installing system package-manager security configs..."
install -d -m 755 /etc/pnpm /etc/bun /etc/profile.d /etc/skel/.config/pnpm
install_file "${NPMRC_SRC}" /etc/npmrc 644
install_file "${PNPMRC_SRC}" /etc/pnpm/rc 644
install_file "${BUNFIG_SRC}" /etc/bun/bunfig.toml 644
install_file "${NODE_PROFILE_SRC}" /etc/profile.d/99-node-security.sh 644
install_file "${UMASK_PROFILE_SRC}" /etc/profile.d/99-security-umask.sh 644

log_info "Installing skel package-manager security configs..."
install_file "${NPMRC_SRC}" /etc/skel/.npmrc 600
install_file "${PNPMRC_SRC}" /etc/skel/.config/pnpm/rc 600
install_file "${BUNFIG_SRC}" /etc/skel/.bunfig.toml 600

log_info "Installing root package-manager security configs..."
copy_user_configs /root root:root

log_info "Installing package-manager security configs for existing users..."
for home_dir in /home/*; do
    [[ -d "${home_dir}" ]] || continue
    [[ "$(basename -- "${home_dir}")" != "lost+found" ]] || continue
    owner_group="$(stat -c '%U:%G' "${home_dir}")"
    copy_user_configs "${home_dir}" "${owner_group}"
done

apply_npm_config_if_available
log_success "Node package-manager security config applied."
