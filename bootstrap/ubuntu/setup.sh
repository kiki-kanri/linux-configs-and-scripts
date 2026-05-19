#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# Bootstrap an Ubuntu server from a raw curl pipe, then run repo-local toolkit scripts.

set -euo pipefail

# Constants
REPO_URL="https://github.com/kiki-kanri/linux-configs-and-scripts"
WORK_DIR="/tmp/linux-configs-and-scripts"
BOOTSTRAP_DIR="${WORK_DIR}/bootstrap/ubuntu"
SHFMT_VERSION="3.13.1"
SSH_PORT=""
TOOLKIT_DIR="${WORK_DIR}/toolkit"
TIMEZONE=""

# Run
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    printf '[setup-ubuntu] ERROR: This script must be run as root.\n' >&2
    exit 1
fi

printf '[setup-ubuntu] INFO: Installing bootstrap dependencies...\n'
apt-get update
apt-get install -y ca-certificates curl git iproute2

printf '[setup-ubuntu] INFO: Cloning linux-configs-and-scripts...\n'
rm -rf "${WORK_DIR}"
git clone "${REPO_URL}" "${WORK_DIR}"

printf '[setup-ubuntu] INFO: Fixing file permissions...\n'
"${WORK_DIR}/modify-files-permissions.sh"

# shellcheck disable=SC1091
source "${WORK_DIR}/libs/common.sh"

# Functions
install_ldu() {
    cat >/usr/local/bin/ldu <<'SCRIPT'
#!/bin/sh
if [ $# -eq 0 ]; then
    du -had1 . | sort -h | column -t
else
    du -had1 "$@" | sort -h | column -t
fi
SCRIPT

    chmod 755 /usr/local/bin/ldu
}

install_rc_local() {
    systemctl enable rc-local.service
    cat >/etc/rc.local <<'SCRIPT'
#!/bin/bash
/scripts/ensure-ssh-host-keys.sh
exit 0
SCRIPT

    chmod 700 /etc/rc.local
}

install_shfmt() {
    local arch
    local shfmt_arch
    local shfmt_url

    arch="$(detect_architecture)"
    case "${arch}" in
    x86_64) shfmt_arch="amd64" ;;
    aarch64) shfmt_arch="arm64" ;;
    esac

    shfmt_url="https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_${shfmt_arch}"
    curl -fsSL "${shfmt_url}" -o /usr/local/bin/shfmt
    chmod 755 /usr/local/bin/shfmt
}

rsync_bootstrap_dir() {
    local dest="$1"
    local old_mode

    old_mode="$(stat -c '%a' "${dest}")"
    rsync -a "${BOOTSTRAP_DIR}/files${dest}" "${dest}"
    chmod "${old_mode}" "${dest}"
}

read_ssh_port() {
    local port

    while true; do
        printf 'Enter SSH port: ' >/dev/tty
        read -r port </dev/tty
        if [[ ! "${port}" =~ ^[0-9]+$ ]]; then
            log_error "Invalid port: must be a number."
            continue
        fi

        if ((port < 1 || port > 65535)); then
            log_error "Invalid port: must be 1-65535."
            continue
        fi

        SSH_PORT="${port}"
        return 0
    done
}

read_timezone() {
    local timezone

    while true; do
        printf 'Enter timezone [Asia/Taipei]: ' >/dev/tty
        read -r timezone </dev/tty
        timezone="${timezone:-Asia/Taipei}"
        if [[ -f "/usr/share/zoneinfo/${timezone}" ]]; then
            TIMEZONE="${timezone}"
            return 0
        fi

        log_error "Invalid timezone: ${timezone}"
    done
}

sync_home_dirs() {
    local user_dir user_name

    log_info "Syncing /etc/skel to existing home directories..."
    for user_dir in /home/*; do
        [[ -d "${user_dir}" ]] || continue
        [[ "$(basename -- "${user_dir}")" != "lost+found" ]] || continue

        user_name="$(basename -- "${user_dir}")"
        rsync -a /etc/skel/ "${user_dir}/"
        chown -R "${user_name}:${user_name}" "${user_dir}"
        chmod 600 "${user_dir}/.bashrc" "${user_dir}/.profile"
        [[ ! -f "${user_dir}/.npmrc" ]] || chmod 600 "${user_dir}/.npmrc"
        [[ ! -f "${user_dir}/.bunfig.toml" ]] || chmod 600 "${user_dir}/.bunfig.toml"
        [[ ! -d "${user_dir}/.config/pnpm" ]] || chmod 700 "${user_dir}/.config/pnpm"
        [[ ! -f "${user_dir}/.config/pnpm/rc" ]] || chmod 600 "${user_dir}/.config/pnpm/rc"
        if [[ -d "${user_dir}/.ssh" ]]; then
            chmod 700 "${user_dir}/.ssh"
            find "${user_dir}/.ssh" -type f -exec chmod 600 {} +
        fi
    done

    log_info "Home directories sync complete."
}

# Run
require_cmd apt-get git curl

"${TOOLKIT_DIR}/install/install-base-packages.sh"
require_cmd basename chmod chown curl find locale-gen rsync sed stat systemctl ufw update-locale

read_ssh_port
log_info "Selected SSH port: ${SSH_PORT}"
read_timezone
log_info "Selected timezone: ${TIMEZONE}"

log_info "Installing bootstrap config files..."
rsync_bootstrap_dir /etc/
rsync_bootstrap_dir /root/
chmod 644 /etc/bash.bashrc /etc/profile /etc/npmrc /etc/pnpm/rc /etc/bun/bunfig.toml /etc/profile.d/99-node-security.sh /etc/profile.d/99-security-umask.sh
chmod 755 /etc/pnpm /etc/bun
chmod 600 /root/.npmrc /root/.config/pnpm/rc /root/.bunfig.toml
chmod 700 /root/.config/pnpm

log_info "Setting SSH port to ${SSH_PORT}..."
sed -i "s/SSH_PORT/${SSH_PORT}/" /etc/ssh/sshd_config

sync_home_dirs

log_info "Installing helper scripts..."
install_ldu

log_info "Setting up ufw..."
sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
ufw allow "${SSH_PORT}"/tcp comment ssh
log_success "UFW rule added. Enable it with: ufw enable"

log_info "Setting locale..."
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

log_info "Installing shfmt..."
install_shfmt

log_info "Setting up rc.local..."
install_rc_local

log_info "Copying scripts..."
install -d -m 755 /scripts
rsync_bootstrap_dir /scripts/

log_info "Running toolkit scripts..."
"${TOOLKIT_DIR}/init/disable-motds.sh"
"${TOOLKIT_DIR}/init/disable-ipv6.sh"
"${TOOLKIT_DIR}/init/setup-locale.sh" -f en_US.UTF-8
"${TOOLKIT_DIR}/init/setup-timezone.sh" -f "${TIMEZONE}"
"${TOOLKIT_DIR}/install/install-7zip.sh"
"${TOOLKIT_DIR}/install/install-cat-motd.sh"
"${TOOLKIT_DIR}/service/setup-thp-tuning.sh"

log_info "Cloning linux-configs-and-scripts to ${SCRIPTS_REPO_DIR}..."
install -d -m 755 /scripts
cd /scripts
rm -rf "${SCRIPTS_REPO_DIR}"
git clone "${REPO_URL}"
"${SCRIPTS_REPO_DIR}/modify-files-permissions.sh"

log_success "Bootstrap complete. Reboot is recommended."
