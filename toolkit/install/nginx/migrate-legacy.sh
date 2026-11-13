#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

# One-off cleanup for hosts built by the old build-nginx.sh (QuicTLS); run after run.sh has succeeded.

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../../libs/common.sh"
source "${SCRIPT_DIR}/config.sh"

# Constants/Variables
readonly LEGACY_QUICTLS_DIR='/opt/quictls-for-nginx'
readonly -a LEGACY_GEOIP_PACKAGES=(geoip-bin geoip-database libgeoip1 libgeoip-dev)

# Functions
# Rewrites websocket-ho-host.conf includes and adds default.conf next to bare websocket.conf includes in the same block.
rewrite_proxy_includes() {
    local file="$1"

    sed -E 's#^([[:space:]]*)include([[:space:]]+)public/proxies/websocket-ho-host\.conf;#\1include public/proxies/default-no-host.conf;\n\1include public/proxies/websocket.conf;#' "${file}" |
        awk '
            function is_proxy_default(line) {
                return line ~ /^[[:space:]]*include[[:space:]]+public\/proxies\/default(-no-host)?\.conf;/
            }

            function block_has_proxy_default(i, j) {
                for (j = i - 1; j >= 1; j--) {
                    if (is_proxy_default(lines[j])) return 1
                    if (lines[j] ~ /\{/) break
                }

                for (j = i + 1; j <= NR; j++) {
                    if (is_proxy_default(lines[j])) return 1
                    if (lines[j] ~ /\}/) break
                }

                return 0
            }

            { lines[NR] = $0 }

            END {
                for (i = 1; i <= NR; i++) {
                    if (lines[i] ~ /^[[:space:]]*include[[:space:]]+public\/proxies\/websocket\.conf;/ && !block_has_proxy_default(i)) {
                        match(lines[i], /^[[:space:]]*/)
                        print substr(lines[i], 1, RLENGTH) "include public/proxies/default.conf;"
                    }

                    print lines[i]
                }
            }
        '
}

migrate_domain_configs() {
    local file
    local -i changed=0

    [[ -d "${NGINX_PREFIX}/domains" ]] || return 0

    while IFS= read -r -d '' file; do
        rewrite_proxy_includes "${file}" >"${rewritten}"
        cmp -s "${file}" "${rewritten}" && continue

        diff -u --label "${file}" --label "${file} (migrated)" "${file}" "${rewritten}" || (($? == 1))
        # Writing in place keeps the owner and mode of the existing file.
        cat "${rewritten}" >"${file}"
        changed+=1
    done < <(find "${NGINX_PREFIX}/domains" -type f -print0 | sort -z)

    log_info "Domain configs updated: ${changed}"
    ((changed == 0)) || domain_configs_changed=true
}

remove_legacy_files() {
    local legacy_snippet="${NGINX_PREFIX}/public/proxies/websocket-ho-host.conf"

    log_info 'Removing legacy QuicTLS, nginx install leftovers and stale binaries...'
    rm -rf -- "${LEGACY_QUICTLS_DIR}" "${NGINX_PREFIX}/html"
    # The .old files are the QuicTLS-linked previous build and cannot run without the QuicTLS directory.
    rm -f -- "${NGINX_SBIN}.old" "${NGINX_MODULES_DIR}"/*.old "${NGINX_MODULES_DIR}/ngx_stream_geoip_module.so"
    rm -f -- "${NGINX_PREFIX}"/*.default "${NGINX_PREFIX}/koi-utf" "${NGINX_PREFIX}/koi-win" "${NGINX_PREFIX}/win-utf"

    if grep -rq 'websocket-ho-host' "${NGINX_PREFIX}/domains" 2>/dev/null; then
        log_warn "websocket-ho-host.conf is still referenced; kept: ${legacy_snippet}"
    else
        rm -f -- "${legacy_snippet}"
    fi

    if [[ -d "${NGINX_PREFIX}/public/ssls" ]]; then
        find "${NGINX_PREFIX}/public/ssls" -type f -name '*.conf' -exec sed -i '/ssl_trusted_certificate/d' {} +
    fi
}

remove_legacy_packages() {
    local package package_status
    local -a installed_packages=()

    # Newer releases may no longer ship these packages; apt-get purge fails on unknown names.
    for package in "${LEGACY_GEOIP_PACKAGES[@]}"; do
        if package_status="$(dpkg-query -W -f='${db:Status-Status}' "${package}" 2>/dev/null)" && [[ "${package_status}" == installed ]]; then
            installed_packages+=("${package}")
        fi
    done

    if ((${#installed_packages[@]} > 0)); then
        log_info 'Purging legacy GeoIP packages...'
        apt-get purge "${installed_packages[@]}" || log_warn 'Legacy GeoIP packages were not purged'
    fi

    log_info 'Removing orphaned packages, including leftovers from old builds...'
    apt-get autoremove --purge || log_warn 'Orphaned packages were not removed'
}

# Run
main() (
    local domain_configs_changed=false
    local rewritten

    require_root
    require_cmd apt-get awk cmp diff dpkg-query find grep mktemp sed sort systemctl

    if [[ ! -f "${NGINX_BUILD_INFO}" ]]; then
        log_error "Run toolkit/install/nginx/run.sh successfully before migrating; missing: ${NGINX_BUILD_INFO}"
        exit 1
    fi

    rewritten="$(mktemp)"
    trap 'rm -f -- "${rewritten}"' EXIT

    migrate_domain_configs
    remove_legacy_files

    if [[ "${domain_configs_changed}" == true ]]; then
        "${NGINX_SBIN}" -t
        systemctl reload nginx
        log_success 'NGINX reloaded with migrated domain configs'
    fi

    remove_legacy_packages
    log_success 'Legacy NGINX migration completed'
)

main "$@"
