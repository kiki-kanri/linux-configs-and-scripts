#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly SOURCE_FILE="${REPO_ROOT}/toolkit/conf/update-motd.d/9999-cat"
readonly DEST_FILE='/etc/update-motd.d/9999-cat'

# Run
main() {
    require_root

    log_info 'Installing Cat MOTD...'
    install -D -o root -g root -m 755 "${SOURCE_FILE}" "${DEST_FILE}"
    log_success "Cat MOTD installed: ${DEST_FILE}"
}

main "$@"
