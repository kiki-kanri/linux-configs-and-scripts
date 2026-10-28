#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly DEFAULT_LOCALE='en_US.UTF-8'
readonly LOCALE_FILE='/etc/locale.gen'

# Functions
list_locales() {
    awk '
        /^[[:space:]]*#?[[:space:]]*[^#[:space:]]+[[:space:]]+UTF-8/ {
            sub(/^[[:space:]]*#?[[:space:]]*/, "")
            print $1
        }
    ' "${LOCALE_FILE}" | sort -u
}

prompt_locale() {
    local selected_locale

    log_info 'Available UTF-8 locales:' >&2
    list_locales >&2
    if [[ -r /dev/tty ]]; then
        printf 'Enter locale [%s]: ' "${DEFAULT_LOCALE}" >/dev/tty
        read -r selected_locale </dev/tty || return 1
    else
        log_info "No interactive terminal; using default locale: ${DEFAULT_LOCALE}" >&2
        selected_locale="${DEFAULT_LOCALE}"
    fi

    printf '%s\n' "${selected_locale:-${DEFAULT_LOCALE}}"
}

# Run
main() {
    local force=false
    local locale='' escaped_locale

    while (($# > 0)); do
        case "$1" in
        -f) force=true ;;
        -*)
            log_error "Unknown option: $1"
            exit 2
            ;;
        *)
            if [[ -n "${locale}" ]]; then
                log_error "Unexpected argument: $1"
                exit 2
            fi

            locale="$1"
            ;;
        esac
        shift
    done

    require_root
    require_cmd locale-gen update-locale
    [[ -n "${locale}" ]] || locale="$(prompt_locale)"
    if ! list_locales | grep -Fx -- "${locale}" >/dev/null; then
        log_error "Locale not available in ${LOCALE_FILE}: ${locale}"
        exit 1
    fi

    if [[ "${force}" == false ]]; then
        confirm "Set locale to ${locale}?" --default=yes || return 0
    fi

    log_info "Generating locale: ${locale}..."
    escaped_locale="${locale//./\\.}"
    sed -i -E "/^[[:space:]]*#[[:space:]]*${escaped_locale}[[:space:]]+UTF-8([[:space:]]|$)/s/^[[:space:]]*#[[:space:]]*//" "${LOCALE_FILE}"
    locale-gen "${locale}"

    log_info 'Setting system default locale...'
    # Let the distribution select its locale file; do not maintain a second copy.
    update-locale --reset LANG="${locale}" LANGUAGE="${locale%%.*}"
    log_success "System locale set: ${locale}"
    log_info 'Log out and back in for the new locale to take effect'
}

main "$@"
