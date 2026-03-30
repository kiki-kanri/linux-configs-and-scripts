#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# build-nginx.sh — Build and install nginx from source with HTTP/3 (QuicTLS)
#
# Builds:
#   - QuicTLS (OpenSSL 3.3.0 + QUIC) as the SSL library
#   - nginx 1.28.3 with HTTP/3, Brotli, GeoIP2, headers-more, zstd
#
# Optimizations:
#   - Clang + thin LTO (Link-Time Optimization)
#   - march=native (CPU-native instruction set)
#   - -fstack-protector-strong, FORTIFY_SOURCE, RELRO, PIE
#   - GSO, quic_retry enabled in nginx.conf
#
# Supports fresh install and upgrade (preserves /etc/nginx/{certs,domains,public,nginx.conf})

set -Eeuo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root

# Toolchain: gcc for QuicTLS (no LTO, assembler flags are gcc-native)
#             clang  for nginx (thin LTO, LINK=clang++)

# ── Versions ───────────────────────────────────────────────────
NGINX_VERSION="1.28.3"
# Default branch already has QUIC support — no tag needed

# ── Paths ──────────────────────────────────────────────────────
TMP_DIR="/tmp/build-nginx"
QUICTLS_DIR="/opt/quictls-for-nginx"
NGINX_BAK="/etc/nginx.bak"
NGINX_USER="nginx"
NGINX_GROUP="nginx"

# ── Build packages ─────────────────────────────────────────────
DEVELOP_PACKAGES=(
    clang
    cmake
    libbrotli-dev
    libgeoip-dev
    libmaxminddb-dev
    libpcre3-dev
    libzstd-dev
    lld
    llvm
    ninja-build
    zlib1g-dev
    g++
    gcc
    pkg-config
    wget
)

RUNTIME_PACKAGES=(
    geoip-bin
    geoip-database
    libbrotli1
    libgeoip1
    libmaxminddb0
    libpcre3
    libzstd1
    zlib1g
)

# ── QuicTLS compile flags (gcc, no LTO) ────────────────────────
QUICTLS_CFLAGS=(
    -fdata-sections
    -ffunction-sections
    -fomit-frame-pointer
    -fPIC
    -fstack-clash-protection
    -fstack-protector-strong
    -fstrict-aliasing
    -g
    -march=native
    -O3
    -pthread
)

QUICTLS_LDFLAGS=()

# ── nginx compile flags ────────────────────────────────────────
NGINX_CC_OPT=(
    -fdata-sections
    -ffunction-sections
    -flto=thin
    -fomit-frame-pointer
    -fPIC
    -fstack-clash-protection
    -fstack-protector-strong
    -I"${QUICTLS_DIR}/build/include"
    -I"${QUICTLS_DIR}/include"
    -march=native
    -O3
    -pthread
    -Werror=format-security
    -Wformat
)

NGINX_LD_OPT=(
    -flto=thin
    -fuse-ld=lld
    -L"${QUICTLS_DIR}/build"
    -ldl
    -lpthread
    -Wl,--as-needed
    -Wl,--gc-sections
    -Wl,-E
    -Wl,-O2
    -Wl,-rpath,"${QUICTLS_DIR}/build"
    -Wl,-z,now
    -Wl,-z,relro
)

# ═══════════════════════════════════════════════════════════════
# Pre-flight checks
# ═══════════════════════════════════════════════════════════════
preflight() {
    require_cmd git cmake ninja

    if systemctl is-active --quiet nginx 2>/dev/null; then
        log_warn "nginx is currently running. Build will restart it."
        confirm "Continue?" --default=yes || exit 0
    fi
}

# ═══════════════════════════════════════════════════════════════
# Source prep
# ═══════════════════════════════════════════════════════════════
prep_sources() {
    log_info "Preparing build directory..."
    rm -rf "${TMP_DIR}"
    mkdir -p "${TMP_DIR}"

    # ── QuicTLS ────────────────────────────────────────────────
    log_info "Cloning QuicTLS..."
    rm -rf "${QUICTLS_DIR}"
    git clone --depth=1 \
        https://github.com/quictls/quictls.git \
        "${QUICTLS_DIR}" &

    # ── Dynamic modules ────────────────────────────────────────
    log_info "Cloning ngx_brotli..."
    git clone --recurse-submodules \
        https://github.com/google/ngx_brotli.git \
        "${TMP_DIR}/ngx_brotli" &

    log_info "Cloning ngx_http_geoip2_module..."
    git clone --recurse-submodules \
        https://github.com/leev/ngx_http_geoip2_module.git \
        "${TMP_DIR}/ngx_http_geoip2_module" &

    log_info "Cloning headers-more-nginx-module..."
    git clone --recurse-submodules \
        https://github.com/openresty/headers-more-nginx-module.git \
        "${TMP_DIR}/headers-more-nginx-module" &

    log_info "Cloning zstd-nginx-module..."
    git clone --recurse-submodules \
        https://github.com/tokers/zstd-nginx-module.git \
        "${TMP_DIR}/zstd-nginx-module" &

    wait
}

# ═══════════════════════════════════════════════════════════════
# Build QuicTLS (single build, point nginx at build tree)
# ═══════════════════════════════════════════════════════════════
build_quictls() {
    log_info "Building QuicTLS (no LTO — avoids version script conflicts)..."

    local build_dir="${QUICTLS_DIR}/build"
    rm -rf "${build_dir}"
    mkdir -p "${build_dir}"

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

# ═══════════════════════════════════════════════════════════════
# Build nginx
# ═══════════════════════════════════════════════════════════════
build_nginx() {
    log_info "Downloading nginx ${NGINX_VERSION}..."
    rm -rf "${TMP_DIR}/nginx-${NGINX_VERSION}" "${TMP_DIR}/nginx-${NGINX_VERSION}.tar.gz"
    wget -q "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" \
        -P "${TMP_DIR}"
    tar -xf "${TMP_DIR}/nginx-${NGINX_VERSION}.tar.gz" -C "${TMP_DIR}"

    local nginx_src="${TMP_DIR}/nginx-${NGINX_VERSION}"

    log_info "Configuring nginx (CC=clang)..."
    cd "${nginx_src}"
    CC=clang CXX=clang++ ./configure \
        --add-dynamic-module=../ngx_http_geoip2_module \
        --add-module=../headers-more-nginx-module \
        --add-module=../ngx_brotli \
        --add-module=../zstd-nginx-module \
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
        --modules-path=/usr/lib/nginx/modules \
        --pid-path=/run/nginx.pid \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
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

    log_info "Compiling nginx (LINK=clang++)..."
    make -j"$(nproc)" LINK=clang++

    log_info "Installing nginx (LINK=clang++)..."
    make install LINK=clang++

    # Strip symbols
    strip -s /usr/sbin/nginx 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════
# Post-install
# ═══════════════════════════════════════════════════════════════
post_install() {
    local is_upgrade="$1"

    # ── User / group ──────────────────────────────────────────
    if ! id -u "${NGINX_USER}" >/dev/null 2>&1; then
        useradd -r -s /sbin/nologin "${NGINX_USER}"
        log_info "Created user: ${NGINX_USER}"
    fi

    # ── Directories ────────────────────────────────────────────
    mkdir -p /var/cache/nginx
    mkdir -p /var/log/nginx
    mkdir -p /etc/nginx/certs

    # ── Upgrade: restore preserved files ───────────────────────
    if [[ "${is_upgrade}" == "true" ]]; then
        log_info "Restoring nginx config from backup..."
        rm -rf \
            /etc/nginx/nginx.conf \
            /etc/nginx/certs \
            /etc/nginx/domains \
            /etc/nginx/public

        cp -fp "${NGINX_BAK}/nginx.conf" /etc/nginx/nginx.conf
        cp -rfp \
            "${NGINX_BAK}/certs" \
            "${NGINX_BAK}/domains" \
            "${NGINX_BAK}/public" \
            /etc/nginx/

        log_info "Config restored from ${NGINX_BAK}/"
    else
        # ── Fresh install: merge toolkit configs into /etc/nginx ─
        rsync -av "${SCRIPT_DIR}/../conf/nginx/" /etc/nginx/

        # systemd unit
        cp -fp "${SCRIPT_DIR}/../conf/systemd/nginx.service" /etc/systemd/system/nginx.service
        systemctl daemon-reload
    fi

    # ── Hold packages ─────────────────────────────────────────
    if command -v apt-mark >/dev/null 2>&1; then
        apt-mark hold nginx nginx-debug 2>/dev/null || true
    fi

    # ── Enable + start ────────────────────────────────────────
    systemctl enable nginx
    systemctl restart nginx

    log_success "nginx ${NGINX_VERSION} installed and started."
}

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════
main() {
    local is_upgrade="false"

    if [[ -f /etc/nginx/nginx.conf ]]; then
        log_info "Detected existing nginx installation."
        log_warn "All files in /etc/nginx will be reset EXCEPT:"
        log_warn "  certs, domains, public, nginx.conf"
        log_warn "Old config will be backed up to ${NGINX_BAK}"
        confirm "Continue with upgrade?" --default=yes || exit 0
        is_upgrade="true"

        log_info "Backing up existing config to ${NGINX_BAK}..."
        if [[ -e "${NGINX_BAK}" ]]; then
            local bak_ts
            bak_ts="$(date '+%Y%m%d%H%M%S')"
            log_info "Existing backup found, rotating to ${NGINX_BAK}.${bak_ts}..."
            mv "${NGINX_BAK}" "${NGINX_BAK}.${bak_ts}"
        fi
        cp -frp /etc/nginx "${NGINX_BAK}"
    fi

    log_info "Installing build dependencies..."
    apt-get update
    apt-get install -y --no-install-recommends "${DEVELOP_PACKAGES[@]}" git

    rm -rf "${TMP_DIR}"
    preflight
    prep_sources
    build_quictls
    build_nginx

    # Install runtime deps and remove build deps
    log_info "Installing runtime dependencies..."
    apt-get install -y "${RUNTIME_PACKAGES[@]}"
    apt-get remove --auto-remove -y "${DEVELOP_PACKAGES[@]}" 2>/dev/null || true

    post_install "${is_upgrade}"

    log_info "Cleaning up build directory..."
    rm -rf "${TMP_DIR}"

    # Verify
    log_info "nginx version: $(/usr/sbin/nginx -v 2>&1)"
    systemctl status nginx --no-pager | grep -E "Active:|loaded:"
}

main "$@"
