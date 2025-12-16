#!/bin/bash

set -euo pipefail

# Functions
log_green() {
    echo -e "\033[32m$*\033[0m"
}

log_red() {
    echo -e "\033[31m$*\033[0m"
}

# Run
cd /tmp
apt-get update
apt-get install -y git
rm -rf ./linux-configs-and-scripts/
git clone https://github.com/kiki-kanri/linux-configs-and-scripts
cd ./linux-configs-and-scripts/
./modify-files-permissions.sh
cd ./ubuntu/24.04/

log_green 'Installing base packages...'
apt-get install -y \
    bash-completion \
    bsdmainutils \
    ca-certificates \
    htop \
    iftop \
    iputils-ping \
    locales \
    lsd \
    lsof \
    net-tools \
    nmap \
    rsync \
    tcpdump \
    tmux \
    tree \
    vim \
    ufw \
    unzip

apt-get remove -y --auto-remove --purge open-vm-tools

log_green 'Configuring...'

# ─────────────────────────────
# Ask for SSH port
# ─────────────────────────────
while true; do
    read -p "Please enter SSH port: " SSH_PORT </dev/tty
    [[ "${SSH_PORT}" =~ ^[0-9]+$ ]] || {
        log_red "Invalid port: must be a number"
        continue
    }

    if (($SSH_PORT < 1 || $SSH_PORT > 65535)); then
        log_red "Invalid port: must be 1-65535"
        continue
    fi

    if [[ "${SSH_PORT}" != "22" ]]; then
        if ss -tulpn | grep -q ":${SSH_PORT}\b"; then
            log_red "Port ${SSH_PORT} is already in use"
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
        log_red "Invalid timezone: ${TIMEZONE}"
    fi
done

# ─────────────────────────────
# Install files
# ─────────────────────────────
log_green 'Installing files...'

OLD_MODE="$(stat -c '%a' /etc)"
rsync -av --progress ./etc/ /etc/
chmod "${OLD_MODE}" /etc

OLD_MODE="$(stat -c '%a' /root)"
rsync -av --progress ./root/ /root/
chmod "${OLD_MODE}" /root

# ─────────────────────────────
# Apply SSH port to sshd_config
# ─────────────────────────────
log_green 'Setting SSH port...'
sed -i "s/'SSH_PORT'/${SSH_PORT}/" /etc/ssh/sshd_config

# ─────────────────────────────
# Install helper scripts
# ─────────────────────────────
log_green 'Installing helper scripts...'
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
log_green 'Setting up ufw...'
sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
ufw allow "${SSH_PORT}"/tcp comment ssh

# ─────────────────────────────
# Set locale
# ─────────────────────────────
log_green 'Setting locale...'
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ─────────────────────────────
# Set timezone
# ─────────────────────────────
log_green 'Setting timezone...'
timedatectl set-timezone "${TIMEZONE}"

# ─────────────────────────────
# Set timezone
# ─────────────────────────────
log_green 'Installing shmft...'
curl -L https://github.com/mvdan/sh/releases/download/v3.12.0/shfmt_v3.12.0_linux_amd64 -o /usr/local/bin/shfmt
chmod +x /usr/local/bin/shfmt

# ─────────────────────────────
# Enable rc-local service and setup
# ─────────────────────────────
log_green 'Enabling rc-local service...'
systemctl enable rc-local.service
rm -rf /etc/rc.local
echo '#!/bin/bash

exit 0
' | tee /etc/rc.local >/dev/null && chmod 700 /etc/rc.local

# ─────────────────────────────
# Copy scripts
# ─────────────────────────────
mkdir /scripts
OLD_MODE="$(stat -c '%a' /scripts)"
rsync -av --progress ./scripts/ /scripts/
chmod "${OLD_MODE}" /scripts

# Done
log_green 'Done, make sure to reboot!'
