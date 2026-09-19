#!/usr/bin/env bash
# Install baseline Debian/Ubuntu packages.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

require_root
require_cmd apt-get

if [[ ! -r /etc/os-release ]]; then
    log_error "Cannot determine the operating system: /etc/os-release is unavailable."
    exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release

release_packages=()
case "${ID:-}:${VERSION_ID:-}" in
debian:13)
    # Debian 13 keeps dnsutils as a virtual package and removed
    # software-properties-common from the release repositories.
    release_packages=(bind9-dnsutils)
    log_info "Using Debian 13 package names."
    ;;
debian:12 | ubuntu:24.04 | ubuntu:26.04)
    release_packages=(dnsutils software-properties-common)
    ;;
*)
    log_error "Unsupported operating system release: ${PRETTY_NAME:-unknown}."
    log_error "Supported releases: Debian 12, Debian 13, Ubuntu 24.04, and Ubuntu 26.04."
    exit 1
    ;;
esac

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
    logrotate
    lsd
    lsof
    ncdu
    net-tools
    netcat-openbsd
    nmap
    psmisc
    ripgrep
    rsync
    screen
    tar
    tcpdump
    tmux
    tree
    ufw
    unzip
    vim
    wget
    whois
)

base_packages+=("${release_packages[@]}")

log_info "Updating package index..."
apt-get update

log_info "Upgrading installed packages..."
apt-get upgrade -y

log_info "Installing base packages..."
apt-get install -y --no-install-recommends "${base_packages[@]}"

log_info "Removing open-vm-tools if present..."
apt-get remove -y --auto-remove --purge open-vm-tools 2>/dev/null || true

log_success "Base packages installed."
