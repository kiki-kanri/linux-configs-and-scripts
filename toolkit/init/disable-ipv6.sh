#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# ipv6.sh — Enable or disable IPv6 on the system
#
# Usage:
#   ipv6.sh --disable    # disable IPv6
#   ipv6.sh --enable     # re-enable IPv6
#   ipv6.sh              # interactive mode (asks)
#
# Effect:  sysctl only (runtime). Survives service restarts.

set -Eeuo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root

SYSCTL_CONF="/etc/sysctl.d/99-disable-ipv6.conf"

is_disabled() {
    [[ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)" == "1" ]]
}

do_disable() {
    local src="${SCRIPT_DIR}/../conf/sysctl.d/99-disable-ipv6.conf"

    if [[ ! -f "${src}" ]]; then
        log_error "sysctl template not found: ${src}"
        exit 1
    fi

    log_info "Installing sysctl config from ${src}..."
    cp -f "${src}" "${SYSCTL_CONF}"
    sysctl -p "${SYSCTL_CONF}" >/dev/null 2>&1 || true
    log_success "IPv6 disabled (runtime)."
}

do_enable() {
    log_info "Re-enabling IPv6..."
    rm -f "${SYSCTL_CONF}"
    sysctl -p "${SYSCTL_CONF}" >/dev/null 2>&1 || true
    # Re-enable manually in case sysctl.conf is gone
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null 2>&1 || true
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null 2>&1 || true
    sysctl -w net.ipv6.conf.lo.disable_ipv6=0 >/dev/null 2>&1 || true
    log_success "IPv6 re-enabled."
}

main() {
    local action=""

    if [[ $# -eq 0 ]]; then
        action="interactive"
    else
        case "$1" in
        --disable | -d) action="disable" ;;
        --enable | -e) action="enable" ;;
        --help | -h)
            echo "Usage: $0 {--disable|--enable}"
            echo "  --disable   disable IPv6"
            echo "  --enable    re-enable IPv6"
            echo "  (no args)  interactive mode"
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1. Use --help."
            exit 1
            ;;
        esac
    fi

    case "${action}" in
    disable)
        if is_disabled; then
            log_info "IPv6 is already disabled."
            exit 0
        fi
        do_disable
        ;;
    enable)
        if ! is_disabled; then
            log_info "IPv6 is already enabled."
            exit 0
        fi
        do_enable
        ;;
    interactive)
        if is_disabled; then
            log_info "IPv6 is currently DISABLED."
            confirm "Re-enable IPv6?" --default=yes || exit 0
            do_enable
        else
            log_info "IPv6 is currently ENABLED."
            confirm "Disable IPv6?" --default=no || exit 0
            do_disable
        fi
        ;;
    esac
}

main "$@"
