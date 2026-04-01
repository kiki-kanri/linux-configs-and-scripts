#!/bin/bash

set -euo pipefail

# Set constants
ROOT_LIB_DIR="../../lib"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
TOOLKIT_DIR="../../toolkit"

# Run
cd /tmp
apt-get update
apt-get install -y git
rm -rf ./linux-configs-and-scripts/
git clone https://github.com/kiki-kanri/linux-configs-and-scripts
cd ./linux-configs-and-scripts/
./modify-files-permissions.sh
cd ./bootstrap/ubuntu/

# Load libs
. "${ROOT_LIB_DIR}/log.sh"
. ./lib.sh

# Install base packages
"${TOOLKIT_DIR}/install/install-base-packages.sh"

# Configure
log_info 'Configuring...'

# ─────────────────────────────
# Ask for SSH port
# ─────────────────────────────
while true; do
    read -p "Please enter SSH port: " SSH_PORT </dev/tty
    [[ "${SSH_PORT}" =~ ^[0-9]+$ ]] || {
        log_error "Invalid port: must be a number"
        continue
    }

    if (($SSH_PORT < 1 || $SSH_PORT > 65535)); then
        log_error "Invalid port: must be 1-65535"
        continue
    fi

    if [[ "${SSH_PORT}" != "22" ]]; then
        if ss -tulpn | grep -q ":${SSH_PORT}\b"; then
            log_error "Port ${SSH_PORT} is already in use"
            continue
        fi
    fi

    break
done

# ─────────────────────────────
# Ask for timezone
# ─────────────────────────────
while true; do
    read -p "Please enter timezone [Asia/Taipei]: " TIMEZONE </dev/tty
    TIMEZONE=${TIMEZONE:-Asia/Taipei}
    if timedatectl list-timezones | grep -qx "${TIMEZONE}"; then
        timedatectl set-timezone "${TIMEZONE}"
        break
    else
        log_error "Invalid timezone: ${TIMEZONE}"
    fi
done

# ─────────────────────────────
# Install files
# ─────────────────────────────
log_info 'Installing files...'
rsync_dir /etc/
rsync_dir /root/

# ─────────────────────────────
# Apply SSH port to sshd_config
# ─────────────────────────────
log_info 'Setting SSH port...'
sed -i "s/'SSH_PORT'/${SSH_PORT}/" /etc/ssh/sshd_config

# ─────────────────────────────
# Install helper scripts
# ─────────────────────────────
log_info 'Installing helper scripts...'
echo '#!/bin/sh

if [ $# -eq 0 ]; then
    du -had1 . | sort -h | column -t
else
    du -had1 "$@" | sort -h | column -t
fi
' | tee /usr/local/bin/ldu >/dev/null && chmod +x /usr/local/bin/ldu

# ─────────────────────────────
# Setup and enable ufw
# ─────────────────────────────
log_info 'Setting up ufw...'
sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
ufw allow "${SSH_PORT}"/tcp comment ssh

# ─────────────────────────────
# Set locale
# ─────────────────────────────
log_info 'Setting locale...'
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ─────────────────────────────
# Set timezone
# ─────────────────────────────
log_info 'Setting timezone...'
timedatectl set-timezone "${TIMEZONE}"

# ─────────────────────────────
# Install shmft
# ─────────────────────────────
log_info 'Installing shmft...'
curl -L https://github.com/mvdan/sh/releases/download/v3.13.0/shfmt_v3.13.0_linux_amd64 -o /usr/local/bin/shfmt
chmod +x /usr/local/bin/shfmt

# ─────────────────────────────
# Enable rc-local service and setup
# ─────────────────────────────
log_info 'Enabling rc-local service...'
systemctl enable rc-local.service
rm -rf /etc/rc.local
echo '#!/bin/bash

/scripts/ensure-ssh-host-keys.sh

exit 0
' | tee /etc/rc.local >/dev/null && chmod 700 /etc/rc.local

# ─────────────────────────────
# Copy scripts
# ─────────────────────────────
log_info 'Copying scripts...'
mkdir -p /scripts
rsync_dir /scripts/

# ─────────────────────────────
# Run toolkit scripts
# ─────────────────────────────
log_info 'Running toolkit scripts...'

"${TOOLKIT_DIR}/init/disable-motds.sh"
"${TOOLKIT_DIR}/init/ipv6.sh" -d
"${TOOLKIT_DIR}/init/setup-locale.sh" -y 'en_US.UTF-8'
"${TOOLKIT_DIR}/init/setup-timezone.sh" -y 'Asia/Taipei'

"${TOOLKIT_DIR}/install/install-7zip.sh" -y
"${TOOLKIT_DIR}/install/install-cat-motd.sh" -y

"${TOOLKIT_DIR}/service/thp-tuning.sh" --enable

# Done
log_success 'Done, make sure to reboot!'
