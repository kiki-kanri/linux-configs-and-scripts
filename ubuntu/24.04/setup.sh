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
cd ./linux-configs-and-scripts/ubuntu/24.04/

log_green 'Installing base packages...'
apt-get install -y bash-completion bsdmainutils htop locales lsd lsof rsync vim ufw

log_green 'Installing files...'

# Ask for SSH port
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

    if ss -tulpn | grep -q ":${SSH_PORT}\b"; then
        log_red "Port ${SSH_PORT} is already in use"
        continue
    fi

    break
done

# Install files
rsync -av --progress ./etc/ /etc/
rsync -av --progress ./root/ /root/
sed -i "s/SSH_PORT/${SSH_PORT}/" /etc/ssh/sshd_config
