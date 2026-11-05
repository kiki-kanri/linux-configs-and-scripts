#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly VIM_MODULES_SRC="${REPO_ROOT}/toolkit/conf/vim/vimrc.d"
readonly VIM_MODULES_DEST='/etc/vim/vimrc.d'
readonly VIMRC_SRC="${REPO_ROOT}/toolkit/conf/vim/vimrc"
readonly VIMRC_DEST='/etc/vim/vimrc'

# Run
main() {
    local ID VERSION_ID PRETTY_NAME

    require_root
    source /etc/os-release
    case "${ID}:${VERSION_ID}" in
    debian:12 | debian:13 | ubuntu:24.04 | ubuntu:26.04) ;;
    *)
        log_error "Unsupported operating system release: ${PRETTY_NAME}"
        exit 1
        ;;
    esac

    log_info 'Validating Vim configuration...'
    vim --clean -u "${VIMRC_SRC}" -i NONE -n -es -c 'quitall'

    log_info "Installing Vim configuration: ${VIMRC_DEST}..."
    install -d -o root -g root -m 755 /etc/vim "${VIM_MODULES_DEST}"
    install -o root -g root -m 644 "${VIM_MODULES_SRC}"/*.vim "${VIM_MODULES_DEST}/"
    install -o root -g root -m 644 "${VIMRC_SRC}" "${VIMRC_DEST}"

    log_success 'Vim configuration installed'
}

main "$@"
