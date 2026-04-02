#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# install-php8.sh — Install PHP 8.5 via Ondrej Sury's PPA/repo
#
# Supports: Debian, Ubuntu
# Packages include common extensions for web development.

set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root

PHP_VERSION="8.5"
PHP_EXTENSIONS=(
    bcmath
    bz2
    cli
    common
    curl
    fpm
    gd
    gmp
    imagick
    imap
    mbstring
    mongodb
    mysql
    pcov
    pq
    raphf
    readline
    redis
    xml
    yaml
    zip
    zstd
)

do_install() {
    log_info "Installing prerequisites..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates lsb-release software-properties-common

    # Add Ondrej PHP repo
    log_info "Adding Ondrej Sury's PHP repository..."
    if ! command -v add-apt-repository >/dev/null 2>&1; then
        apt-get install -y software-properties-common
    fi
    add-apt-repository -y ppa:ondrej/php

    apt-get update

    # Build package list
    local packages=()
    for ext in "${PHP_EXTENSIONS[@]}"; do
        packages+=("php${PHP_VERSION}-${ext}")
    done

    log_info "Installing PHP ${PHP_VERSION} packages..."
    apt-get install -y "${packages[@]}"

    log_info "Enabling and starting php${PHP_VERSION}-fpm..."
    systemctl enable "php${PHP_VERSION}-fpm"
    systemctl start "php${PHP_VERSION}-fpm"

    log_success "PHP ${PHP_VERSION} installed."
}

post_install() {
    log_info "PHP version : $(php --version 2>/dev/null | head -1 || echo 'N/A')"
    log_info "FPM status  : $(systemctl is-active "php${PHP_VERSION}-fpm" 2>/dev/null || echo 'N/A')"
    log_info "Composer    : $(command -v composer >/dev/null 2>&1 && echo 'found' || echo 'not found — run: curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer')"
}

main() {
    if command -v php >/dev/null 2>&1; then
        local current_version
        current_version="$(php --version 2>/dev/null | head -1 || echo '')"
        log_info "PHP is already installed: ${current_version}"
        confirm "Re-install PHP ${PHP_VERSION}?" --default=no || exit 0
    fi

    do_install
    post_install
}

main "$@"
