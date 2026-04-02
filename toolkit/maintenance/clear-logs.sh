#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# clear-logs.sh — Clear old log files from /var/log
#
# Removes rotated/compressed logs older than ${DAYS} days.
# Targets: *.gz, *.[0-9], *.[0-9].gz, old, timestamped logs.

set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root

DAYS="${DAYS:-7}"

do_clear() {
    local count=0
    local size=0

    log_info "Clearing logs older than ${DAYS} days in /var/log..."

    # Find and remove old compressed/rotated logs
    while IFS= read -r -d '' file; do
        local fsize
        fsize="$(stat -c%s "${file}" 2>/dev/null || echo 0)"
        rm -f "${file}"
        ((count++))
        ((size += fsize))
        log_info "  Removed: ${file}"
    done < <(find /var/log -type f \( \
        -name "*.gz" -o \
        -name "*.[0-9]" -o \
        -name "*.[0-9].gz" -o \
        -name "*.old" -o \
        -name "*-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]" \
        \) -mtime +"${DAYS}" -print0 2>/dev/null)

    local size_mb=$((size / 1024 / 1024))
    log_success "Cleared ${count} files (approx ${size_mb} MB freed)."
}

main() {
    log_info "This will remove compressed/rotated log files older than ${DAYS} days."
    log_info "Active log files are NOT touched."
    confirm "Proceed?" --default=yes || exit 0

    do_clear
}

main "$@"
