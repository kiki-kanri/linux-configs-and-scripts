#!/usr/bin/env bash

# shellcheck disable=SC1091

# Build and install nginx with HTTP/3, QuicTLS, Brotli, GeoIP2, headers-more and zstd.

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"
source "${SCRIPT_DIR}/build-nginx.d/settings.sh"
source "${SCRIPT_DIR}/build-nginx.d/packages.sh"
source "${SCRIPT_DIR}/build-nginx.d/sources.sh"
source "${SCRIPT_DIR}/build-nginx.d/flags.sh"

# Functions
is_build_package_preinstalled() {
    local package
    for package in "${preinstalled_build_packages[@]}"; do
        [[ "${package}" == "$1" ]] && return 0
    done

    return 1
}

backup_existing_nginx() {
    [[ -f /etc/nginx/nginx.conf ]] || return 0

    log_info 'Existing NGINX installation detected'
    log_warn 'Upgrade preserves nginx.conf, certs, conf.d, domains and public; source: /etc/nginx'
    if [[ "${force}" == false ]]; then
        confirm 'Continue with NGINX upgrade?' --default=yes || exit 0
    fi

    is_upgrade=true
    if [[ -e "${NGINX_BACKUP_DIR}" ]]; then
        local backup_timestamp
        backup_timestamp="$(date '+%Y%m%d%H%M%S')"
        log_info "Rotating existing backup to: ${NGINX_BACKUP_DIR}.${backup_timestamp}..."
        mv "${NGINX_BACKUP_DIR}" "${NGINX_BACKUP_DIR}.${backup_timestamp}"
    fi

    log_info "Backing up NGINX configuration to: ${NGINX_BACKUP_DIR}..."
    cp -a /etc/nginx "${NGINX_BACKUP_DIR}"
}

install_build_dependencies() {
    log_info 'Installing NGINX build dependencies...'
    apt-get update

    local package package_status
    for package in "${BUILD_PACKAGES[@]}"; do
        if package_status="$(dpkg-query -W -f='${db:Status-Status}' "${package}" 2>/dev/null)" && [[ "${package_status}" == installed ]]; then
            preinstalled_build_packages+=("${package}")
        fi
    done

    apt-get install -y --no-install-recommends "${BUILD_PACKAGES[@]}" "${BUILD_TOOLS[@]}"
    require_cmd clang cmake git make ninja rsync strip wget
}

prepare_sources() {
    log_info 'Cloning QuicTLS...'
    rm -rf "${QUICTLS_DIR}"
    git clone --depth=1 "${QUICTLS_REPO_URL}" "${QUICTLS_DIR}"

    log_info 'Cloning NGINX modules...'
    local module_repo module_name repo_url
    for module_repo in "${NGINX_MODULE_REPOS[@]}"; do
        IFS='|' read -r module_name repo_url <<<"${module_repo}"
        git clone --recurse-submodules "${repo_url}" "${build_root_dir}/${module_name}"
    done
}

build_brotli() {
    local brotli_src_dir="${build_root_dir}/ngx_brotli/deps/brotli"
    local build_dir="${brotli_src_dir}/out"

    log_info "Preparing Brotli version: ${BROTLI_VERSION}..."
    git -C "${brotli_src_dir}" fetch --depth=1 origin "refs/tags/v${BROTLI_VERSION}"
    git -C "${brotli_src_dir}" checkout --detach FETCH_HEAD

    log_info 'Building Brotli...'
    rm -rf "${build_dir}"
    install -d -m 755 "${build_dir}"

    cmake \
        -S "${brotli_src_dir}" \
        -B "${build_dir}" \
        -GNinja \
        -DBROTLI_BUILD_TOOLS=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_FLAGS_RELEASE="${BROTLI_CFLAGS[*]}" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON

    ninja -C "${build_dir}" -j"$(nproc)" brotlienc brotlicommon
    log_success "Brotli built; version: ${BROTLI_VERSION}"
}

build_quictls() {
    local build_dir="${QUICTLS_DIR}/build"

    log_info 'Building QuicTLS...'
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
    log_success 'QuicTLS built'
}

download_nginx() {
    log_info "Downloading NGINX version: ${NGINX_VERSION}..."
    rm -rf "${build_root_dir}/nginx-${NGINX_VERSION}" "${build_root_dir}/nginx-${NGINX_VERSION}.tar.gz"
    wget -q "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -P "${build_root_dir}"
    tar -xf "${build_root_dir}/nginx-${NGINX_VERSION}.tar.gz" -C "${build_root_dir}"
}

build_and_install_nginx() {
    local nginx_src_dir="${build_root_dir}/nginx-${NGINX_VERSION}"

    log_info 'Configuring NGINX...'
    (
        cd "${nginx_src_dir}"
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
            --with-cc-opt="${NGINX_CFLAGS[*]}" \
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
            --with-ld-opt="${NGINX_LDFLAGS[*]}" \
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

        log_info 'Compiling NGINX...'
        make -j"$(nproc)" LINK=clang++

        log_info 'Installing NGINX...'
        make install LINK=clang++
    )

    strip -s "${NGINX_SBIN}" 2>/dev/null || true
}

restore_or_install_config() {
    if [[ "${is_upgrade}" == true ]]; then
        log_info 'Restoring preserved NGINX configuration...'
        rm -rf /etc/nginx/nginx.conf /etc/nginx/certs /etc/nginx/domains /etc/nginx/public
        cp -a "${NGINX_BACKUP_DIR}/nginx.conf" /etc/nginx/nginx.conf

        local item
        for item in certs conf.d domains public; do
            [[ -e "${NGINX_BACKUP_DIR}/${item}" ]] || continue
            cp -a "${NGINX_BACKUP_DIR}/${item}" /etc/nginx/
        done

        return 0
    fi

    log_info 'Installing default NGINX configuration...'
    rsync -a "${REPO_ROOT}/toolkit/conf/nginx/" /etc/nginx/
    install_file "${REPO_ROOT}/toolkit/conf/systemd/nginx.service" /etc/systemd/system/nginx.service 644
    systemctl daemon-reload
}

finish_nginx_installation() {
    if ! id -u "${NGINX_USER}" >/dev/null 2>&1; then
        useradd -r -s /sbin/nologin "${NGINX_USER}"
        log_info "NGINX user created: ${NGINX_USER}"
    fi

    install -d -m 755 /var/cache/nginx /var/log/nginx /etc/nginx/certs
    restore_or_install_config

    if command_exists apt-mark; then
        apt-mark hold nginx nginx-debug 2>/dev/null || true
    fi

    "${NGINX_SBIN}" -t
    systemctl enable nginx
    systemctl restart nginx
    log_success "NGINX installed and started; version: ${NGINX_VERSION}"
}

setup_nginx_integrations() {
    # cloudflare
    local setup_script="${REPO_ROOT}/toolkit/service/setup-cloudflare-nginx.sh"
    if [[ ! -x "${setup_script}" ]]; then
        log_warn "Cloudflare NGINX setup script is missing or not executable; skipping: ${setup_script}"
    else
        log_info 'Setting up Cloudflare IP range auto-update for NGINX...'
        "${setup_script}" || log_warn "Cloudflare NGINX auto-update setup failed; run manually: ${setup_script}"
    fi

    # logrotate
    setup_script="${REPO_ROOT}/toolkit/service/setup-logrotate-nginx.sh"
    if [[ ! -x "${setup_script}" ]]; then
        log_warn "NGINX logrotate setup script is missing or not executable; skipping: ${setup_script}"
    else
        log_info 'Setting up NGINX logrotate policy...'
        "${setup_script}" || log_warn "NGINX logrotate setup failed; run manually: ${setup_script}"
    fi
}

cleanup_build_dependencies() {
    log_info 'Installing runtime packages and removing build-only packages...'
    apt-get install -y --no-install-recommends "${RUNTIME_PACKAGES[@]}"

    local package
    local packages_to_remove=()
    for package in "${BUILD_PACKAGES[@]}"; do
        if ! is_build_package_preinstalled "${package}"; then
            packages_to_remove+=("${package}")
        fi
    done

    if ((${#packages_to_remove[@]} > 0)); then
        apt-get remove --purge -y "${packages_to_remove[@]}" 2>/dev/null || true
    else
        log_info 'All build packages were already installed; skipping build package removal'
    fi
}

# Run
main() (
    local force=false
    local is_upgrade=false
    local preinstalled_build_packages=()
    local build_root_dir

    while (($# > 0)); do
        case "$1" in
        -f)
            force=true
            shift
            ;;
        -v)
            [[ -n "${2:-}" ]] || {
                log_error "Missing value for option: $1"
                exit 1
            }
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
    require_cmd apt-get cp date dpkg-query grep id install mktemp mv nproc rm systemctl tar useradd

    if [[ ! -f /etc/nginx/nginx.conf ]] && systemctl is-active --quiet nginx 2>/dev/null && [[ "${force}" == false ]]; then
        log_warn 'NGINX is running and will be restarted'
        confirm 'Continue?' --default=yes || exit 0
    fi

    build_root_dir="$(mktemp -d /tmp/build-nginx.XXXXXX)"
    trap 'rm -rf -- "${build_root_dir}"' EXIT

    backup_existing_nginx
    install_build_dependencies
    prepare_sources
    build_brotli
    build_quictls
    download_nginx
    build_and_install_nginx
    cleanup_build_dependencies
    finish_nginx_installation
    setup_nginx_integrations
    log_info "$("${NGINX_SBIN}" -v 2>&1)"
    systemctl status nginx --no-pager | grep -E 'Active:|Loaded:' || true
)

main "$@"
