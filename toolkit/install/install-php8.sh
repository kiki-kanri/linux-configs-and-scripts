#!/usr/bin/env bash
# Install or refresh PHP with common extensions via Ondrej Sury's repository.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

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

force=false
packages=()

while (($# > 0)); do
    case "$1" in
    -f)
        force=true
        shift
        ;;
    -*)
        log_error "Unknown option: $1"
        exit 1
        ;;
    *)
        log_error "Unexpected argument: $1"
        exit 1
        ;;
    esac
done

require_root
require_cmd apt-get head

if command_exists php && [[ "${force}" == false ]]; then
    log_info "PHP is already installed: $(php --version 2>/dev/null | head -1 || printf 'version unknown')"
    log_info "Use -f to reinstall PHP ${PHP_VERSION}."
else
    log_info "Installing PHP repository prerequisites..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates lsb-release software-properties-common

    log_info "Adding Ondrej Sury PHP repository..."
    require_cmd add-apt-repository
    add-apt-repository -y ppa:ondrej/php

    apt-get update

    for extension in "${PHP_EXTENSIONS[@]}"; do
        packages+=("php${PHP_VERSION}-${extension}")
    done

    log_info "Installing PHP ${PHP_VERSION} packages..."
    apt-get install -y "${packages[@]}"

    if command_exists systemctl; then
        log_info "Enabling and starting php${PHP_VERSION}-fpm..."
        systemctl enable "php${PHP_VERSION}-fpm" || log_warn "Could not enable php${PHP_VERSION}-fpm."
        systemctl restart "php${PHP_VERSION}-fpm" || log_warn "Could not start php${PHP_VERSION}-fpm."
    else
        log_warn "systemctl not found; skipping php${PHP_VERSION}-fpm service setup."
    fi

    log_success "PHP ${PHP_VERSION} installed."
fi

log_info "PHP version : $(php --version 2>/dev/null | head -1 || printf 'N/A')"
log_info "FPM status  : $(systemctl is-active "php${PHP_VERSION}-fpm" 2>/dev/null || printf 'N/A')"
log_info "Composer    : $(command_exists composer && printf 'found' || printf 'not found — run: curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer')"
