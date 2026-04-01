#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# install-base-packages.sh — Install base packages

set -Eeuo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root

log_info "Installing base packages..."
apt-get update
apy-get upgrade -y
apt-get install -y --no-install-recommends \
    bash-completion \
    bsdmainutils \
    ca-certificates \
    cron \
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
    unzip \
    acl \
    htop \
    iotop \
    screen \
    tar \
    wget

apt-get remove -y --auto-remove --purge open-vm-tools
log_success "Base packages installed"
