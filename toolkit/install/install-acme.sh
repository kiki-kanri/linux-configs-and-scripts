#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# Install or refresh root-managed acme.sh for nginx certificate automation.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

ACME_REPO="https://github.com/acmesh-official/acme.sh.git"
ACME_DIR="${HOME}/.acme.sh"
ACME_BIN="${ACME_DIR}/acme.sh"
email=""
force=false
tmpdir=""

cleanup() {
    [[ -z "${tmpdir}" ]] || rm -rf "${tmpdir}"
}

read_email() {
    local input=""

    if [[ -r /dev/tty ]]; then
        printf 'Enter account email for acme.sh: ' >/dev/tty
        read -r input </dev/tty || input=""
    fi

    printf '%s\n' "${input}"
}

validate_email() {
    [[ "$1" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]
}

install_cron_if_possible() {
    if command_exists cron || command_exists crond; then
        return 0
    fi

    if command_exists apt-get; then
        log_info "Installing cron for acme.sh renewal jobs..."
        apt-get update >/dev/null
        apt-get install -y cron
    else
        log_warn "cron is not installed and no supported package manager was found."
        log_warn "acme.sh renewal jobs may not be scheduled automatically."
    fi
}

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
        if [[ -n "${email}" ]]; then
            log_error "Unexpected extra argument: $1"
            exit 1
        fi
        email="$1"
        shift
        ;;
    esac
done

require_root
require_cmd git curl head rm mktemp

[[ -n "${email}" ]] || email="$(read_email)"
if ! validate_email "${email}"; then
    log_error "Invalid email address: ${email:-empty}"
    exit 1
fi

install_cron_if_possible

if [[ -e "${ACME_DIR}" ]]; then
    if [[ -x "${ACME_BIN}" ]]; then
        log_info "Existing acme.sh detected: $(${ACME_BIN} --version 2>/dev/null | head -1 || printf 'version unknown')"
    else
        log_info "Existing ${ACME_DIR} detected."
    fi

    if [[ "${force}" == false ]]; then
        confirm "Replace ${ACME_DIR}?" --default=no || exit 0
    else
        log_info "Force mode: replacing ${ACME_DIR}."
    fi

    rm -rf "${ACME_DIR}"
fi

tmpdir="$(mktemp -d)"
trap cleanup EXIT

log_info "Cloning acme.sh..."
git clone --depth=1 "${ACME_REPO}" "${tmpdir}"

log_info "Running acme.sh installer for ${email}..."
(cd "${tmpdir}" && ./acme.sh --install -m "${email}")

[[ -x "${ACME_BIN}" ]] || {
    log_error "acme.sh installer finished, but ${ACME_BIN} was not created."
    exit 1
}

log_info "Setting default CA to Let's Encrypt..."
"${ACME_BIN}" --set-default-ca --server letsencrypt

log_info "Enabling acme.sh auto-upgrade..."
"${ACME_BIN}" --upgrade --auto-upgrade

log_success "acme.sh installed for root-managed certificate automation."
log_info "Command: ${ACME_BIN}"
log_info "Account email: ${email}"
