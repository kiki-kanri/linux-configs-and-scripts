#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# install-cat-motd.sh — Install the cat MOTD banner script
#
# Copies conf/update-motd.d/9999-cat to /etc/update-motd.d/ and sets permissions.

set -Eeuo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root

SRC="${SCRIPT_DIR}/../conf/update-motd.d/9999-cat"
DEST="/etc/update-motd.d/9999-cat"

do_install() {
    if [[ ! -f "${SRC}" ]]; then
        log_error "Source file not found: ${SRC}"
        exit 1
    fi

    log_info "Installing cat MOTD script..."
    cp -f "${SRC}" "${DEST}"
    chmod 755 "${DEST}"
    log_success "Installed: ${DEST}"
}

do_uninstall() {
    if [[ ! -f "${DEST}" ]]; then
        log_info "cat MOTD script is not installed."
        return 0
    fi
    log_info "Removing cat MOTD script..."
    rm -f "${DEST}"
    log_success "Removed: ${DEST}"
}

main() {
    local action=""

    case "${1:-}" in
    --uninstall | -u) action="uninstall" ;;
    --help | -h)
        echo "Usage: $0 [--uninstall]"
        exit 0
        ;;
    "")
        if [[ -f "${DEST}" ]]; then
            log_info "cat MOTD script is already installed."
            confirm "Reinstall?" --default=no && action="install" || exit 0
        else
            action="install"
        fi
        ;;
    *)
        log_error "Unknown argument: $1"
        exit 1
        ;;
    esac

    case "${action}" in
    install) do_install ;;
    uninstall) do_uninstall ;;
    esac
}

main "$@"
