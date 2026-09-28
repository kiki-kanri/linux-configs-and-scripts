#!/usr/bin/env bash
# Fetch Cloudflare IP ranges and generate nginx real_ip and origin-access config.

set -euo pipefail

CF_IPV4_URL="${CF_IPV4_URL:-https://www.cloudflare.com/ips-v4}"
CF_IPV6_URL="${CF_IPV6_URL:-https://www.cloudflare.com/ips-v6}"
CF_API_URL="${CF_API_URL:-https://api.cloudflare.com/client/v4/ips}"
CLOUDFLARE_DIR="${CLOUDFLARE_DIR:-/etc/nginx/conf.d}"
CLOUDFLARE_CONF="${CLOUDFLARE_CONF:-${CLOUDFLARE_DIR}/cloudflare-nginx.conf}"
RELOAD_NGINX="${RELOAD_NGINX:-1}"
TMP_DIR=""

cleanup() {
    [[ -z "${TMP_DIR}" ]] || rm -rf "${TMP_DIR}"
}

log() {
    printf '[cloudflare-nginx] %s\n' "$*"
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
        log "Cloudflare ${label} range mismatch between text endpoint and API endpoint."
        diff -u "${list_file}" "${api_file}" || true
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
    if [[ "${RELOAD_NGINX}" == "0" || "${RELOAD_NGINX}" == "false" ]]; then
        log "nginx reload disabled by RELOAD_NGINX=${RELOAD_NGINX}."
        return 0
    fi

    if ! command -v nginx >/dev/null 2>&1; then
        log "nginx not found; generated config only."
        return 0
    fi

    nginx -t || return 1

    if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet nginx 2>/dev/null; then
        systemctl reload nginx || return 1
        log "nginx reloaded."
        return 0
    fi

    log "nginx config is valid; service is not active or systemctl unavailable."
}

main() {
    local had_existing=0
    local previous_config

    command -v curl >/dev/null 2>&1 || {
        log "curl is required."
        exit 1
    }

    command -v python3 >/dev/null 2>&1 || {
        log "python3 is required."
        exit 1
    }

    command -v install >/dev/null 2>&1 || {
        log "install is required."
        exit 1
    }

    TMP_DIR="$(mktemp -d)"
    trap cleanup EXIT

    log "Fetching Cloudflare IPv4 ranges..."
    curl -fsSL --retry 3 --connect-timeout 10 --output "${TMP_DIR}/ips-v4" "${CF_IPV4_URL}"

    log "Fetching Cloudflare IPv6 ranges..."
    curl -fsSL --retry 3 --connect-timeout 10 --output "${TMP_DIR}/ips-v6" "${CF_IPV6_URL}"

    log "Fetching Cloudflare API IP ranges..."
    curl -fsSL --retry 3 --connect-timeout 10 --output "${TMP_DIR}/api-ips.json" "${CF_API_URL}"

    extract_api_cidrs "${TMP_DIR}/api-ips.json" "${TMP_DIR}/api-ips-v4" "${TMP_DIR}/api-ips-v6"
    normalize_cidrs "${TMP_DIR}/ips-v4" "${TMP_DIR}/ips-v4.normalized"
    normalize_cidrs "${TMP_DIR}/ips-v6" "${TMP_DIR}/ips-v6.normalized"
    normalize_cidrs "${TMP_DIR}/api-ips-v4" "${TMP_DIR}/api-ips-v4.normalized"
    normalize_cidrs "${TMP_DIR}/api-ips-v6" "${TMP_DIR}/api-ips-v6.normalized"
    verify_sources_match "${TMP_DIR}/ips-v4.normalized" "${TMP_DIR}/api-ips-v4.normalized" IPv4
    verify_sources_match "${TMP_DIR}/ips-v6.normalized" "${TMP_DIR}/api-ips-v6.normalized" IPv6

    generate_config "${TMP_DIR}/ips-v4.normalized" "${TMP_DIR}/ips-v6.normalized" "${TMP_DIR}/cloudflare-nginx.conf"

    install -d -m 755 "${CLOUDFLARE_DIR}"
    if [[ -f "${CLOUDFLARE_CONF}" ]] && cmp -s "${TMP_DIR}/cloudflare-nginx.conf" "${CLOUDFLARE_CONF}"; then
        log "Cloudflare nginx config already up to date: ${CLOUDFLARE_CONF}"
        return 0
    fi

    previous_config="${TMP_DIR}/previous-cloudflare-nginx.conf"
    if [[ -f "${CLOUDFLARE_CONF}" ]]; then
        cp -f "${CLOUDFLARE_CONF}" "${previous_config}"
        had_existing=1
    fi

    if ! install -m 644 "${TMP_DIR}/cloudflare-nginx.conf" "${CLOUDFLARE_CONF}" || ! validate_and_reload_nginx; then
        if ((had_existing)); then
            install -m 644 "${previous_config}" "${CLOUDFLARE_CONF}"
        else
            rm -f "${CLOUDFLARE_CONF}"
        fi

        log "Cloudflare nginx update failed; config reverted."
        return 1
    fi

    log "Installed Cloudflare nginx config: ${CLOUDFLARE_CONF}"
}

main "$@"
