# -*- mode: bash; tab-size: 4; -*-
# log.sh — Logging utilities for linux-configs-and-scripts
#
# Usage: Set SCRIPT_NAME before sourcing, then call log_info/warn/error/success.
#   SCRIPT_NAME="$(basename "$0" .sh)"
#   source "${LIB_DIR}/log.sh"
#
# Color output is disabled when:
#   - SCRIPT_NAME is empty (avoids blank codes in logs)
#   - NO_COLOR env var is set
#   - stdout is not a terminal (redirected output)

_colorize() {
    if [[ -z "${SCRIPT_NAME:-}" ]] || [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
        printf '%s\n' "$2"
    else
        printf '%s\n' "$1"
    fi
}

log_info() {
    local msg="[${SCRIPT_NAME:-script}] INFO:  $*"
    local colored
    colored="$(printf '\033[36m%s\033[0m' "${msg}")"
    _colorize "${colored}" "${msg}"
}

log_warn() {
    local msg="[${SCRIPT_NAME:-script}] WARN:  $*"
    local colored
    colored="$(printf '\033[33m%s\033[0m' "${msg}")"
    _colorize "${colored}" "${msg}" >&2
}

log_error() {
    local msg="[${SCRIPT_NAME:-script}] ERROR: $*"
    local colored
    colored="$(printf '\033[31m%s\033[0m' "${msg}")"
    _colorize "${colored}" "${msg}" >&2
}

log_success() {
    local msg="[${SCRIPT_NAME:-script}] SUCCESS: $*"
    local colored
    colored="$(printf '\033[32m%s\033[0m' "${msg}")"
    _colorize "${colored}" "${msg}"
}

# Optional: verbose logging (only when VERBOSE=1)
log_debug() {
    [[ "${VERBOSE:-0}" == "1" ]] || [[ "${VERBOSE:-}" == "yes" ]] || [[ "${VERBOSE:-}" == "true" ]] || return 0
    local msg="[${SCRIPT_NAME:-script}] DEBUG: $*"
    printf '%s\n' "${msg}" >&2
}
