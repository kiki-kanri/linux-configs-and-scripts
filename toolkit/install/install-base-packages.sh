#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# Install baseline Debian/Ubuntu packages.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

base_packages=(
    acl
    bash-completion
    bsdmainutils
    ca-certificates
    cron
    git
    htop
    iftop
    iotop
    iputils-ping
    jq
    locales
    lsd
    lsof
    net-tools
    netcat-openbsd
    nmap
    psmisc
    rsync
    screen
    software-properties-common
    tar
    tcpdump
    tmux
    tree
    ufw
    unzip
    vim
    wget
)

require_root
require_cmd apt-get

log_info "Updating package index..."
apt-get update

log_info "Upgrading installed packages..."
apt-get upgrade -y

log_info "Installing base packages..."
apt-get install -y --no-install-recommends "${base_packages[@]}"

log_info "Removing open-vm-tools if present..."
apt-get remove -y --auto-remove --purge open-vm-tools 2>/dev/null || true

log_success "Base packages installed."
