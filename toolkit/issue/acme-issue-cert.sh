#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# Issue and install a wildcard ECC certificate with root-managed acme.sh.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

DOMAIN=""
CERT_DIR="/etc/nginx/certs"
RELOAD_CMD="systemctl reload nginx"
DNS_PROVIDER="cloudflare"
FORCE=false
ACME_BIN="${HOME}/.acme.sh/acme.sh"

need_arg() {
    [[ -n "${2:-}" ]] || {
        log_error "$1 requires a value."
        exit 1
    }
}

normalize_dns_provider() {
    local provider="$1"

    case "${provider}" in
    cloudflare | cf | dns_cf)
        printf 'dns_cf\n'
        ;;
    dns_*)
        printf '%s\n' "${provider}"
        ;;
    *)
        printf 'dns_%s\n' "${provider}"
        ;;
    esac
}

validate_domain() {
    local domain="$1"

    [[ -n "${domain}" ]] || return 1
    [[ "${domain}" != *'*'* ]] || return 1
    [[ "${domain}" != *'/'* ]] || return 1
    [[ "${domain}" != *[[:space:]]* ]] || return 1
    [[ "${domain}" == *.* ]] || return 1
}

require_cloudflare_env() {
    local missing=()

    [[ -n "${CF_Token:-}" ]] || missing+=(CF_Token)
    [[ -n "${CF_Account_ID:-}" ]] || missing+=(CF_Account_ID)
    [[ -n "${CF_Zone_ID:-}" ]] || missing+=(CF_Zone_ID)

    ((${#missing[@]} == 0)) || {
        log_error "Cloudflare DNS requires: ${missing[*]}"
        log_error "Export them and run with sudo -E, or pass them after sudo."
        exit 1
    }

    export CF_Token CF_Account_ID CF_Zone_ID
}

while (($# > 0)); do
    case "$1" in
    -d)
        need_arg "$1" "${2:-}"
        DOMAIN="$2"
        shift 2
        ;;
    -p)
        need_arg "$1" "${2:-}"
        DNS_PROVIDER="$2"
        shift 2
        ;;
    -c)
        need_arg "$1" "${2:-}"
        CERT_DIR="$2"
        shift 2
        ;;
    -r)
        need_arg "$1" "${2:-}"
        RELOAD_CMD="$2"
        shift 2
        ;;
    -f)
        FORCE=true
        shift
        ;;
    -*)
        log_error "Unknown option: $1"
        exit 1
        ;;
    *)
        if [[ -n "${DOMAIN}" ]]; then
            log_error "Unexpected extra argument: $1"
            exit 1
        fi
        DOMAIN="$1"
        shift
        ;;
    esac
done

if ! validate_domain "${DOMAIN}"; then
    log_error "Invalid or missing domain: ${DOMAIN:-empty}"
    log_error "Usage: ${0##*/} [-f] [-p provider] [-c cert_dir] [-r reload_cmd] -d example.com"
    exit 1
fi

require_root
require_cmd chmod install mkdir

DNS_MODE="$(normalize_dns_provider "${DNS_PROVIDER}")"
if [[ "${DNS_MODE}" == "dns_cf" ]]; then
    require_cloudflare_env
else
    log_warn "Using acme.sh DNS provider: ${DNS_MODE}. Make sure its required env vars are set."
fi

[[ -x "${ACME_BIN}" ]] || {
    log_error "acme.sh not found: ${ACME_BIN}"
    log_error "Install it first with toolkit/install/install-acme.sh."
    exit 1
}

ECC_DIR="${CERT_DIR%/}/${DOMAIN}/ecc"
install -d -m 700 "${ECC_DIR}"

issue_cmd=(
    "${ACME_BIN}" --issue
    -d "${DOMAIN}"
    -d "*.${DOMAIN}"
    --dns "${DNS_MODE}"
    --keylength ec-384
    --server letsencrypt
)

[[ "${FORCE}" == false ]] || issue_cmd+=(--force)

log_info "Issuing ECC-384 certificate for ${DOMAIN} and *.${DOMAIN}..."
log_info "DNS provider: ${DNS_MODE}"

if ! "${issue_cmd[@]}"; then
    log_error "Certificate issuance failed."
    if [[ "${DNS_MODE}" == "dns_cf" ]]; then
        log_error "Check Cloudflare zone status and token DNS edit permission."
    fi

    exit 1
fi

log_info "Installing certificate to ${ECC_DIR}..."
"${ACME_BIN}" \
    --install-cert \
    -d "${DOMAIN}" \
    --ecc \
    --ca-file "${ECC_DIR}/chain.pem" \
    --cert-file "${ECC_DIR}/cert.pem" \
    --fullchain-file "${ECC_DIR}/fullchain.pem" \
    --key-file "${ECC_DIR}/key.pem" \
    --reloadcmd "${RELOAD_CMD}"

chmod 600 "${ECC_DIR}/key.pem"
chmod 644 "${ECC_DIR}/chain.pem" "${ECC_DIR}/cert.pem" "${ECC_DIR}/fullchain.pem"

log_success "ECC certificate installed."
log_info "Domain: ${DOMAIN}"
log_info "Certificate dir: ${ECC_DIR}"
log_info "Fullchain: ${ECC_DIR}/fullchain.pem"
log_info "Private key: ${ECC_DIR}/key.pem"
log_info "Reload cmd: ${RELOAD_CMD}"
log_info "Renewal: managed by acme.sh cron job"
