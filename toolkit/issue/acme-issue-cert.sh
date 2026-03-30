#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# acme-issue-cert.sh — Issue and install an ECC SSL certificate via acme.sh (DNS-01 only)
#
# Usage:
#   acme-issue-cert.sh --domain example.com --dns cloudflare
#   acme-issue-cert.sh --domain example.com --dns clouddns \
#       --cert-dir /etc/nginx/certs --reload-cmd "systemctl reload nginx"
#
# DNS-01 challenge (no port required, recommended for wildcard):
#   Cloudflare: export CF_Token, CF_Account_ID, CF_Zone_ID, then --dns cloudflare
#   Other providers: see acme.sh wiki for --dns dns_<provider>

set -Eeuo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

# ── Default values ────────────────────────────────────────────
DOMAIN=""
CERT_DIR="/etc/nginx/certs"
RELOAD_CMD="systemctl reload nginx"
DNS_MODE="" # e.g. "dns_cf" (cloudflare), "dns_clouddns" (tencent), etc.
FORCE_FLAG=""

# ── Argument parsing ───────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --cert-dir)
            CERT_DIR="$2"
            shift 2
            ;;
        --reload-cmd)
            RELOAD_CMD="$2"
            shift 2
            ;;
        --dns)
            case "$2" in
            cloudflare) DNS_MODE="dns_cf" ;;
            *) DNS_MODE="dns_$2" ;;
            esac
            shift 2
            ;;
        --force | -f)
            FORCE_FLAG="--force"
            shift
            ;;
        --help | -h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1 (use --help)"
            exit 1
            ;;
        esac
    done
}

show_help() {
    cat <<'EOF'
Usage: acme-issue-cert.sh [options]

Options:
  --domain DOMAIN       Domain to issue certificate for (required)
  --cert-dir PATH       Directory to store certificates [default: /etc/nginx/certs]
  --reload-cmd CMD      Command to reload service after renewal [default: systemctl reload nginx]
  --dns PROVIDER        DNS provider for DNS-01 challenge (e.g. cloudflare, clouddns)
                        Required env vars per provider: see acme.sh wiki
                        Cloudflare: CF_Token, CF_Account_ID, CF_Zone_ID
  --force, -f           Force re-issuance even if a valid cert already exists (acme.sh --force)

Examples:
  # Cloudflare DNS-01
  export CF_Token=*** CF_Account_ID=id CF_Zone_ID=zone_id
  acme-issue-cert.sh -d example.com --dns cloudflare
EOF
}

# ── Parse arguments ───────────────────────────────────────────
parse_args "$@"

# ── Validation ───────────────────────────────────────────────
if [[ -z "${DOMAIN}" ]]; then
    log_error "--domain is required. (use --help for usage)"
    exit 1
fi

if [[ -z "${DNS_MODE}" ]]; then
    log_error "--dns is required. (e.g. --dns cloudflare)"
    exit 1
fi

# ── DNS mode setup ────────────────────────────────────────────
if [[ -n "${DNS_MODE}" ]]; then
    case "${DNS_MODE}" in
    dns_cf)
        if [[ -z "${CF_Token:-}" ]] || [[ -z "${CF_Account_ID:-}" ]] || [[ -z "${CF_Zone_ID:-}" ]]; then
            log_error "Cloudflare DNS selected but CF_Token, CF_Account_ID, or CF_Zone_ID is not set."
            log_error "Export them before running:"
            log_error "  export CF_Token='your_token'"
            log_error "  export CF_Account_ID='your_account_id'"
            log_error "  export CF_Zone_ID='your_zone_id'"
            exit 1
        fi
        export CF_Token CF_Account_ID CF_Zone_ID
        ;;
    *)
        log_error "Unknown DNS provider: ${DNS_MODE}. Edit script or use --dns cloudflare."
        exit 1
        ;;
    esac
fi

# ── Check acme.sh ─────────────────────────────────────────────
ACMEBIN="${HOME}/.acme.sh/acme.sh"
if [[ ! -x "${ACMEBIN}" ]]; then
    log_error "acme.sh not found at ${ACMEBIN}"
    log_error "Run install-acme.sh first."
    exit 1
fi

# ── Certificate directory ─────────────────────────────────────
ECC_DIR="${CERT_DIR}/${DOMAIN}/ecc"
mkdir -p "${ECC_DIR}"

# ── Issue ECC-384 certificate ────────────────────────────────
ISSUE_CMD=(
    "${ACMEBIN}" --issue
    -d "${DOMAIN}"
    -d "*.${DOMAIN}"
    --dns "${DNS_MODE}"
    --keylength ec-384
    --server letsencrypt
    ${FORCE_FLAG}
)

log_info "Issuing ECC-384 certificate for ${DOMAIN}..."
log_info "Command: ${ISSUE_CMD[*]}"

if ! "${ISSUE_CMD[@]}"; then
    log_error "Certificate issuance failed."
    if [[ "${DNS_MODE}" == "dns_cf" ]]; then
        log_error "Check that CF_Token has Zone:DNS:Edit permission."
        log_error "and that the domain is active in Cloudflare."
    fi
    exit 1
fi

# ── Install certificate ───────────────────────────────────────
log_info "Installing certificate to ${ECC_DIR}..."

"${ACMEBIN}" \
    --install-cert \
    -d "${DOMAIN}" \
    --ecc \
    --ca-file "${ECC_DIR}/chain.pem" \
    --cert-file "${ECC_DIR}/cert.pem" \
    --fullchain-file "${ECC_DIR}/fullchain.pem" \
    --key-file "${ECC_DIR}/key.pem" \
    --reloadcmd "${RELOAD_CMD}"

log_success "ECC certificate issued and installed!"
log_info "Certificate dir : ${ECC_DIR}"
log_info "Fullchain       : ${ECC_DIR}/fullchain.pem"
log_info "Private key     : ${ECC_DIR}/key.pem"
log_info "Reload cmd      : ${RELOAD_CMD}"
log_info "Auto-renewal    : managed by acme.sh cron job"
