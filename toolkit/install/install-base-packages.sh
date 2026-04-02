#!/bin/bash
# install-base-packages.sh — Install base packages

set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root

log_info "Updating package index..."
apt-get update

log_info "Upgrading packages..."
apt-get upgrade -y

log_info "Installing base packages..."
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
    git \
    jq \
    netcat-openbsd \
    psmisc \
    software-properties-common \
    tcpdump \
    tmux \
    tree \
    vim \
    ufw \
    unzip \
    acl \
    iotop \
    screen \
    tar \
    wget

log_info "Removing open-vm-tools..."
apt-get remove -y --auto-remove --purge open-vm-tools

log_success "Base packages installed"
