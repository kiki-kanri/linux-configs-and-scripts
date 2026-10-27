#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly SOURCE_FILE="${REPO_ROOT}/toolkit/bin/git-deep-gc"
readonly DEST_FILE='/usr/local/bin/git-deep-gc'

# Run
main() {
    require_root

    log_info 'Installing git-deep-gc...'
    install -D -o root -g root -m 755 "${SOURCE_FILE}" "${DEST_FILE}"
    log_success "git-deep-gc installed: ${DEST_FILE}"
}

main "$@"
