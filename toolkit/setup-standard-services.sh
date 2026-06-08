#!/usr/bin/env bash
# Run standard server setup tasks and refresh detected service snippets.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/libs/common.sh"

# Functions
run_script() {
    local script_path="$1"

    require_file "${script_path}"
    log_info "Running ${script_path#"${REPO_ROOT}/"}..."
    "${script_path}"
}

nginx_is_installed() {
    command_exists nginx || [[ -d /etc/nginx || -f /etc/nginx/nginx.conf ]]
}

copy_nginx_public_dir() {
    local name="$1"
    local src_dir="${REPO_ROOT}/toolkit/conf/nginx/public/${name}"
    local dest_dir="/etc/nginx/public/${name}"

    require_dir "${src_dir}"
    log_info "Copying nginx public ${name} snippets to ${dest_dir}..."
    install -d -m 755 "${dest_dir}"
    cp -R "${src_dir}/." "${dest_dir}/"
    chown -R root:root "${dest_dir}"
    find "${dest_dir}" -type d -exec chmod 755 {} +
    find "${dest_dir}" -type f -exec chmod 644 {} +
}

refresh_nginx_public_snippets() {
    local ssl_src="${REPO_ROOT}/toolkit/conf/nginx/public/ssls/example.conf"
    local ssl_dest="/etc/nginx/public/ssls/example.conf"

    copy_nginx_public_dir headers
    copy_nginx_public_dir locations
    copy_nginx_public_dir proxies

    require_file "${ssl_src}"
    log_info "Copying nginx SSL example snippet to ${ssl_dest}..."
    install -d -m 755 "$(dirname -- "${ssl_dest}")"
    cp -f "${ssl_src}" "${ssl_dest}"
    chown root:root "${ssl_dest}"
    chmod 644 "${ssl_dest}"
}

if (($# > 0)); then
    log_error "Unexpected argument: $1"
    exit 1
fi

require_root
require_cmd chmod chown cp dirname find install

run_script "${REPO_ROOT}/toolkit/init/disable-motds.sh"
run_script "${REPO_ROOT}/toolkit/install/install-7zip.sh"
run_script "${REPO_ROOT}/toolkit/install/install-base-packages.sh"
run_script "${REPO_ROOT}/toolkit/install/install-cat-motd.sh"
run_script "${REPO_ROOT}/toolkit/install/install-ldu.sh"
run_script "${REPO_ROOT}/toolkit/install/install-shfmt.sh"
run_script "${REPO_ROOT}/toolkit/security/setup-fail2ban.sh"

if command_exists node; then
    run_script "${REPO_ROOT}/toolkit/security/setup-node-package-security.sh"
else
    log_info "node not found; skipping Node package-manager security setup."
fi

if nginx_is_installed; then
    run_script "${REPO_ROOT}/toolkit/service/setup-cloudflare-realip-nginx.sh"
    refresh_nginx_public_snippets
else
    log_info "nginx not found; skipping Cloudflare real IP setup and nginx public snippet refresh."
fi

log_success "Standard service setup complete."
