#!/usr/bin/env bash

# shellcheck shell=bash

set -euo pipefail

# Constants/Variables
readonly CF_API_URL="${CF_API_URL:-https://api.cloudflare.com/client/v4/ips}"
readonly CF_IPV4_URL="${CF_IPV4_URL:-https://www.cloudflare.com/ips-v4}"
readonly CF_IPV6_URL="${CF_IPV6_URL:-https://www.cloudflare.com/ips-v6}"
readonly CLOUDFLARE_DIR="${CLOUDFLARE_DIR:-/etc/nginx/conf.d}"
readonly CLOUDFLARE_CONF="${CLOUDFLARE_CONF:-${CLOUDFLARE_DIR}/cloudflare-nginx.conf}"
readonly RELOAD_NGINX="${RELOAD_NGINX:-1}"

# Functions

# Installed as a standalone file under /usr/local/sbin; repo libraries are unavailable.
log_info() {
    printf '[cloudflare-nginx] INFO: %s\n' "$*"
}

log_success() {
    printf '[cloudflare-nginx] SUCCESS: %s\n' "$*"
}

log_warn() {
    printf '[cloudflare-nginx] WARN: %s\n' "$*" >&2
}

log_error() {
    printf '[cloudflare-nginx] ERROR: %s\n' "$*" >&2
}

normalize_cidrs() {
    local input_file="$1"
    local output_file="$2"

    python3 - "${input_file}" "${output_file}" <<'PY'
import ipaddress
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
dest = pathlib.Path(sys.argv[2])
networks = []

for raw in src.read_text().splitlines():
    line = raw.strip()
    if not line:
        continue

    try:
        networks.append(ipaddress.ip_network(line, strict=False))
    except ValueError as exc:
        raise SystemExit(f"invalid CIDR {line!r} in {src}: {exc}")

if not networks:
    raise SystemExit(f"no CIDRs found in {src}")

networks = sorted(set(networks), key=lambda net: (net.version, int(net.network_address), net.prefixlen))
dest.write_text("".join(f"{net}\n" for net in networks))
PY
}

extract_api_cidrs() {
    local input_file="$1"
    local ipv4_output="$2"
    local ipv6_output="$3"

    python3 - "${input_file}" "${ipv4_output}" "${ipv6_output}" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())
if not data.get("success", False):
    raise SystemExit("Cloudflare API response did not report success")

result = data.get("result") or {}
pathlib.Path(sys.argv[2]).write_text("".join(f"{cidr}\n" for cidr in result.get("ipv4_cidrs", [])))
pathlib.Path(sys.argv[3]).write_text("".join(f"{cidr}\n" for cidr in result.get("ipv6_cidrs", [])))
PY
}

verify_sources_match() {
    local list_file="$1"
    local api_file="$2"
    local label="$3"

    if ! cmp -s "${list_file}" "${api_file}"; then
        log_error "Cloudflare ${label} ranges differ between text and API sources"
        # A nonzero diff status is expected; retain the explicit failure status below.
        diff -u "${list_file}" "${api_file}" >&2 || true
        exit 1
    fi
}

generate_config() {
    local ipv4_file="$1"
    local ipv6_file="$2"
    local output_file="$3"

    {
        cat <<CONFIG
# Managed by update-cloudflare-nginx. Do not edit manually.
# Sources: ${CF_IPV4_URL}, ${CF_IPV6_URL}, and ${CF_API_URL}

real_ip_header CF-Connecting-IP;
real_ip_recursive on;
CONFIG
        sed 's/^/set_real_ip_from /; s/$/;/' "${ipv4_file}" "${ipv6_file}"
        cat <<'CONFIG'

# Match the original TCP peer, not the visitor IP from CF-Connecting-IP.
# Use only in opted-in server blocks via public/access/cloudflare-only.conf.
geo $realip_remote_addr $from_cloudflare {
    default 0;
CONFIG
        sed 's/^/    /; s/$/ 1;/' "${ipv4_file}" "${ipv6_file}"
        printf '}\n'
    } >"${output_file}"
}

validate_and_reload_nginx() {
    local force_reload="${1:-false}"

    if [[ "${force_reload}" == false && ("${RELOAD_NGINX}" == '0' || "${RELOAD_NGINX}" == 'false') ]]; then
        log_info "NGINX reload disabled; RELOAD_NGINX: ${RELOAD_NGINX}"
        return 0
    fi

    /usr/sbin/nginx -t || return 1

    if systemctl is-active --quiet nginx.service; then
        systemctl reload nginx.service || return 1
        log_success 'NGINX reloaded'
        return 0
    fi

    log_info 'NGINX configuration is valid; service is inactive'
}

# Run
main() (
    local force_reload=false
    local had_existing=0
    local previous_config
    local tmp_dir
    local command_name

    while (($# > 0)); do
        case "$1" in
        --force-reload)
            force_reload=true
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            return 1
            ;;
        *)
            log_error "Unexpected argument: $1"
            return 1
            ;;
        esac
    done

    if [[ ! -x /usr/sbin/nginx ]]; then
        log_info 'Nginx is not installed; skipping Cloudflare update'
        return 0
    fi

    for command_name in curl python3 install systemctl; do
        command -v "${command_name}" >/dev/null 2>&1 || {
            log_error "Required command not found: ${command_name}"
            return 1
        }
    done

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf -- "${tmp_dir}"' EXIT

    log_info 'Fetching Cloudflare IPv4 ranges...'
    curl -fsSL --connect-timeout 10 --output "${tmp_dir}/ips-v4" "${CF_IPV4_URL}"

    log_info 'Fetching Cloudflare IPv6 ranges...'
    curl -fsSL --connect-timeout 10 --output "${tmp_dir}/ips-v6" "${CF_IPV6_URL}"

    log_info 'Fetching Cloudflare API IP ranges...'
    curl -fsSL --connect-timeout 10 --output "${tmp_dir}/api-ips.json" "${CF_API_URL}"

    extract_api_cidrs "${tmp_dir}/api-ips.json" "${tmp_dir}/api-ips-v4" "${tmp_dir}/api-ips-v6"
    normalize_cidrs "${tmp_dir}/ips-v4" "${tmp_dir}/ips-v4.normalized"
    normalize_cidrs "${tmp_dir}/ips-v6" "${tmp_dir}/ips-v6.normalized"
    normalize_cidrs "${tmp_dir}/api-ips-v4" "${tmp_dir}/api-ips-v4.normalized"
    normalize_cidrs "${tmp_dir}/api-ips-v6" "${tmp_dir}/api-ips-v6.normalized"
    verify_sources_match "${tmp_dir}/ips-v4.normalized" "${tmp_dir}/api-ips-v4.normalized" IPv4
    verify_sources_match "${tmp_dir}/ips-v6.normalized" "${tmp_dir}/api-ips-v6.normalized" IPv6

    generate_config "${tmp_dir}/ips-v4.normalized" "${tmp_dir}/ips-v6.normalized" "${tmp_dir}/cloudflare-nginx.conf"

    install -d -m 755 "${CLOUDFLARE_DIR}"
    if [[ -f "${CLOUDFLARE_CONF}" ]] && cmp -s "${tmp_dir}/cloudflare-nginx.conf" "${CLOUDFLARE_CONF}"; then
        log_info "Cloudflare NGINX configuration is already up to date: ${CLOUDFLARE_CONF}"
        if [[ "${force_reload}" == true ]]; then
            validate_and_reload_nginx "${force_reload}"
        fi

        return 0
    fi

    previous_config="${tmp_dir}/previous-cloudflare-nginx.conf"
    if [[ -f "${CLOUDFLARE_CONF}" ]]; then
        cp -f "${CLOUDFLARE_CONF}" "${previous_config}"
        had_existing=1
    fi

    if ! install -m 644 "${tmp_dir}/cloudflare-nginx.conf" "${CLOUDFLARE_CONF}" || ! validate_and_reload_nginx "${force_reload}"; then
        if ((had_existing)); then
            install -m 644 "${previous_config}" "${CLOUDFLARE_CONF}"
        else
            rm -f "${CLOUDFLARE_CONF}"
        fi

        log_error 'Cloudflare NGINX update failed; configuration reverted'
        return 1
    fi

    log_success "Cloudflare NGINX configuration installed: ${CLOUDFLARE_CONF}"
)

main "$@"
