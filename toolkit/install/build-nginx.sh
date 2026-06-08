#!/usr/bin/env bash
# Build and install nginx with HTTP/3, QuicTLS, Brotli, GeoIP2, headers-more and zstd.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/build-nginx.d/settings.sh"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/build-nginx.d/packages.sh"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/build-nginx.d/sources.sh"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/build-nginx.d/flags.sh"

force=false
is_upgrade=false

need_arg() {
    [[ -n "${2:-}" ]] || {
        log_error "$1 requires a value."
        exit 1
    }
}

backup_existing_nginx() {
    [[ -f /etc/nginx/nginx.conf ]] || return 0

    log_info "Detected existing nginx installation."
    log_warn "Upgrade keeps only nginx.conf, certs, domains and public from the old /etc/nginx."
    if [[ "${force}" == false ]]; then
        confirm "Continue with nginx upgrade?" --default=yes || exit 0
    fi

    is_upgrade=true
    if [[ -e "${NGINX_BACKUP_DIR}" ]]; then
        local backup_suffix
        backup_suffix="$(date '+%Y%m%d%H%M%S')"
        log_info "Rotating existing backup to ${NGINX_BACKUP_DIR}.${backup_suffix}"
        mv "${NGINX_BACKUP_DIR}" "${NGINX_BACKUP_DIR}.${backup_suffix}"
    fi

    log_info "Backing up /etc/nginx to ${NGINX_BACKUP_DIR}"
    cp -a /etc/nginx "${NGINX_BACKUP_DIR}"
}

install_build_dependencies() {
    log_info "Installing nginx build dependencies..."
    apt-get update
    apt-get install -y --no-install-recommends "${BUILD_PACKAGES[@]}" "${BUILD_TOOLS[@]}"
    require_cmd clang cmake git make ninja rsync strip wget
}

prepare_sources() {
    log_info "Preparing source directories..."
    rm -rf "${TMP_DIR}"
    install -d -m 755 "${TMP_DIR}"

    log_info "Cloning QuicTLS..."
    rm -rf "${QUICTLS_DIR}"
    git clone --depth=1 "${QUICTLS_REPO}" "${QUICTLS_DIR}"

    log_info "Cloning nginx modules..."
    local module module_name repo_url
    for module in "${NGINX_MODULE_REPOS[@]}"; do
        IFS="|" read -r module_name repo_url <<<"${module}"
        git clone --recurse-submodules "${repo_url}" "${TMP_DIR}/${module_name}"
    done
}

build_quictls() {
    local build_dir="${QUICTLS_DIR}/build"

    log_info "Building QuicTLS..."
    rm -rf "${build_dir}"
    install -d -m 755 "${build_dir}"

    cmake \
        -S "${QUICTLS_DIR}" \
        -B "${build_dir}" \
        -GNinja \
        -DOPENSSL_NO_TESTS=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
        -DCMAKE_C_FLAGS_RELEASE="${QUICTLS_CFLAGS[*]}" \
        -DCMAKE_CXX_FLAGS_RELEASE="${QUICTLS_CFLAGS[*]}" \
        -DCMAKE_EXE_LINKER_FLAGS_RELEASE="${QUICTLS_LDFLAGS[*]}" \
        -DCMAKE_SHARED_LINKER_FLAGS_RELEASE="${QUICTLS_LDFLAGS[*]}"

    ninja -C "${build_dir}" -j"$(nproc)"
    log_success "QuicTLS built."
}

download_nginx() {
    log_info "Downloading nginx ${NGINX_VERSION}..."
    rm -rf "${TMP_DIR}/nginx-${NGINX_VERSION}" "${TMP_DIR}/nginx-${NGINX_VERSION}.tar.gz"
    wget -q "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -P "${TMP_DIR}"
    tar -xf "${TMP_DIR}/nginx-${NGINX_VERSION}.tar.gz" -C "${TMP_DIR}"
}

configure_and_build_nginx() {
    local nginx_src="${TMP_DIR}/nginx-${NGINX_VERSION}"

    log_info "Configuring nginx..."
    (
        cd "${nginx_src}"
        CC=clang CXX=clang++ ./configure \
            "${NGINX_MODULE_CONFIGURE_ARGS[@]}" \
            --conf-path=/etc/nginx/nginx.conf \
            --error-log-path=/var/log/nginx/error.log \
            --group="${NGINX_GROUP}" \
            --http-client-body-temp-path=/var/cache/nginx/client_temp \
            --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
            --http-log-path=/var/log/nginx/access.log \
            --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
            --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
            --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
            --lock-path=/run/nginx.lock \
            --modules-path="${NGINX_MODULES_DIR}" \
            --pid-path=/run/nginx.pid \
            --prefix="${NGINX_PREFIX}" \
            --sbin-path="${NGINX_SBIN}" \
            --user="${NGINX_USER}" \
            --with-cc-opt="${NGINX_CC_OPT[*]}" \
            --with-compat \
            --with-file-aio \
            --with-http_addition_module \
            --with-http_auth_request_module \
            --with-http_dav_module \
            --with-http_degradation_module \
            --with-http_flv_module \
            --with-http_gunzip_module \
            --with-http_gzip_static_module \
            --with-http_mp4_module \
            --with-http_random_index_module \
            --with-http_realip_module \
            --with-http_secure_link_module \
            --with-http_slice_module \
            --with-http_ssl_module \
            --with-http_stub_status_module \
            --with-http_sub_module \
            --with-http_v2_module \
            --with-http_v3_module \
            --with-ld-opt="${NGINX_LD_OPT[*]}" \
            --with-mail \
            --with-mail_ssl_module \
            --without-poll_module \
            --without-select_module \
            --with-pcre-jit \
            --with-stream \
            --with-stream_geoip_module=dynamic \
            --with-stream_realip_module \
            --with-stream_ssl_module \
            --with-stream_ssl_preread_module \
            --with-threads

        log_info "Compiling nginx..."
        make -j"$(nproc)" LINK=clang++

        log_info "Installing nginx..."
        make install LINK=clang++
    )

    strip -s "${NGINX_SBIN}" 2>/dev/null || true
}

restore_or_install_config() {
    if [[ "${is_upgrade}" == true ]]; then
        log_info "Restoring preserved nginx config..."
        rm -rf /etc/nginx/nginx.conf /etc/nginx/certs /etc/nginx/domains /etc/nginx/public
        cp -a "${NGINX_BACKUP_DIR}/nginx.conf" /etc/nginx/nginx.conf

        local item
        for item in certs domains public; do
            [[ -e "${NGINX_BACKUP_DIR}/${item}" ]] || continue
            cp -a "${NGINX_BACKUP_DIR}/${item}" /etc/nginx/
        done

        return 0
    fi

    log_info "Installing default nginx config..."
    rsync -a "${REPO_ROOT}/toolkit/conf/nginx/" /etc/nginx/
    install_file "${REPO_ROOT}/toolkit/conf/systemd/nginx.service" /etc/systemd/system/nginx.service 644
    systemctl daemon-reload
}

finish_install() {
    if ! id -u "${NGINX_USER}" >/dev/null 2>&1; then
        useradd -r -s /sbin/nologin "${NGINX_USER}"
        log_info "Created user: ${NGINX_USER}"
    fi

    install -d -m 755 /var/cache/nginx /var/log/nginx /etc/nginx/certs
    restore_or_install_config

    if command_exists apt-mark; then
        apt-mark hold nginx nginx-debug 2>/dev/null || true
    fi

    "${NGINX_SBIN}" -t
    systemctl enable nginx
    systemctl restart nginx
    log_success "nginx ${NGINX_VERSION} installed and started."
}

setup_logrotate() {
    local setup_script="${REPO_ROOT}/toolkit/service/setup-logrotate-nginx.sh"

    if [[ ! -x "${setup_script}" ]]; then
        log_warn "nginx logrotate setup script not found; skipping."
        return 0
    fi

    log_info "Setting up nginx logrotate policy..."
    "${setup_script}" || log_warn "nginx logrotate setup failed; run ${setup_script} manually."
}

setup_cloudflare_realip() {
    local setup_script="${REPO_ROOT}/toolkit/service/setup-cloudflare-realip-nginx.sh"

    if [[ ! -x "${setup_script}" ]]; then
        log_warn "Cloudflare real IP setup script not found; skipping."
        return 0
    fi

    log_info "Setting up Cloudflare real IP auto-update for nginx..."
    "${setup_script}" || log_warn "Cloudflare real IP auto-update setup failed; run ${setup_script} manually."
}

cleanup_build_dependencies() {
    log_info "Removing build-only packages and installing runtime packages..."
    apt-get remove --auto-remove --purge -y "${BUILD_PACKAGES[@]}" 2>/dev/null || true
    apt-get install -y --no-install-recommends "${RUNTIME_PACKAGES[@]}"
}

verify_install() {
    log_info "nginx version: $("${NGINX_SBIN}" -v 2>&1)"
    systemctl status nginx --no-pager | grep -E 'Active:|Loaded:' || true
}

while (($# > 0)); do
    case "$1" in
    -f)
        force=true
        shift
        ;;
    -v)
        need_arg "$1" "${2:-}"
        NGINX_VERSION="$2"
        shift 2
        ;;
    -*)
        log_error "Unknown option: $1"
        exit 1
        ;;
    *)
        log_error "Unexpected argument: $1"
        exit 1
        ;;
    esac
done

require_root
require_cmd apt-get cp date grep id install mv nproc rm systemctl tar useradd

if [[ ! -f /etc/nginx/nginx.conf ]] && systemctl is-active --quiet nginx 2>/dev/null && [[ "${force}" == false ]]; then
    log_warn "nginx is currently running and will be restarted."
    confirm "Continue?" --default=yes || exit 0
fi

backup_existing_nginx
install_build_dependencies
prepare_sources
build_quictls
download_nginx
configure_and_build_nginx
cleanup_build_dependencies
finish_install
setup_logrotate
setup_cloudflare_realip
rm -rf "${TMP_DIR}"
verify_install
