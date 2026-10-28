#!/usr/bin/env bash

# shellcheck shell=bash
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
prepare_existing_installation() {
    local backup_timestamp

    if [[ -f "${NGINX_PREFIX}/nginx.conf" ]]; then
        is_upgrade=true
        log_info 'Existing NGINX installation detected'
        log_warn "Upgrade preserves nginx.conf, certs, conf.d, domains and public; source: ${NGINX_PREFIX}"
    elif systemctl is-active --quiet nginx; then
        log_warn 'NGINX is running and will be restarted'
    else
        return 0
    fi

    if [[ "${force}" == false ]]; then
        confirm 'Continue with NGINX installation?' --default=yes || exit 0
    fi

    [[ "${is_upgrade}" == true ]] || return 0

    if [[ -e "${NGINX_BACKUP_DIR}" ]]; then
        backup_timestamp="$(date '+%Y%m%d%H%M%S')"
        log_info "Rotating existing backup to: ${NGINX_BACKUP_DIR}.${backup_timestamp}..."
        mv "${NGINX_BACKUP_DIR}" "${NGINX_BACKUP_DIR}.${backup_timestamp}"
    fi

    log_info "Backing up NGINX configuration to: ${NGINX_BACKUP_DIR}..."
    cp -a "${NGINX_PREFIX}" "${NGINX_BACKUP_DIR}"
}

install_build_dependencies() {
    local package package_status

    log_info 'Installing NGINX build dependencies...'
    apt-get update

    for package in "${BUILD_PACKAGES[@]}"; do
        if ! package_status="$(dpkg-query -W -f='${db:Status-Status}' "${package}" 2>/dev/null)" || [[ "${package_status}" != installed ]]; then
            new_build_packages+=("${package}")
        fi
    done

    apt-get install -y --no-install-recommends "${BUILD_PACKAGES[@]}" "${BUILD_TOOLS[@]}"
    require_cmd clang cmake git gpg gpgv make ninja rsync strip wget
}

prepare_sources() {
    local module_repo module_name repo_url source_commit

    log_info 'Cloning QuicTLS...'
    rm -rf "${QUICTLS_DIR}"
    git clone --depth=1 "${QUICTLS_REPO_URL}" "${QUICTLS_DIR}"
    source_commit="$(git -C "${QUICTLS_DIR}" rev-parse HEAD)"
    log_info "QuicTLS commit: ${source_commit}"

    log_info 'Cloning NGINX modules...'
    for module_repo in "${NGINX_MODULE_REPOS[@]}"; do
        IFS='|' read -r module_name repo_url <<<"${module_repo}"
        git clone --recurse-submodules "${repo_url}" "${build_root_dir}/${module_name}"
        source_commit="$(git -C "${build_root_dir}/${module_name}" rev-parse HEAD)"
        log_info "${module_name} commit: ${source_commit}"
    done
}

build_brotli() {
    local source_commit
    local brotli_src_dir="${build_root_dir}/ngx_brotli/deps/brotli"
    local build_dir="${brotli_src_dir}/out"

    log_info "Preparing Brotli version: ${BROTLI_VERSION}..."
    git -C "${brotli_src_dir}" fetch --depth=1 origin "refs/tags/v${BROTLI_VERSION}"
    git -C "${brotli_src_dir}" checkout --detach FETCH_HEAD
    source_commit="$(git -C "${brotli_src_dir}" rev-parse HEAD)"
    log_info "Brotli commit: ${source_commit}; version: ${BROTLI_VERSION}"

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
    local archive="${build_root_dir}/nginx-${NGINX_VERSION}.tar.gz"
    local gpg_home="${build_root_dir}/gnupg"

    log_info "Downloading and verifying NGINX version: ${NGINX_VERSION}..."
    wget -q "${NGINX_DOWNLOAD_URL}/nginx-${NGINX_VERSION}.tar.gz" -O "${archive}"
    wget -q "${NGINX_DOWNLOAD_URL}/nginx-${NGINX_VERSION}.tar.gz.asc" -O "${archive}.asc"

    install -d -m 700 "${gpg_home}"
    gpg --batch --yes --homedir "${gpg_home}" --dearmor --output "${gpg_home}/trusted.gpg" "${NGINX_SIGNING_KEYS}"
    gpgv --homedir "${gpg_home}" --keyring "${gpg_home}/trusted.gpg" "${archive}.asc" "${archive}"
    tar -xf "${archive}" -C "${build_root_dir}"
}

build_and_install_nginx() {
    local nginx_src_dir="${build_root_dir}/nginx-${NGINX_VERSION}"

    log_info 'Configuring NGINX...'
    (
        cd "${nginx_src_dir}"
        CC=clang CXX=clang++ ./configure "${NGINX_CONFIGURE_ARGS[@]}"

        log_info 'Compiling NGINX...'
        make -j"$(nproc)" LINK=clang++

        log_info 'Installing NGINX...'
        make install LINK=clang++
    )

    strip -s "${NGINX_SBIN}" || log_warn "Could not strip NGINX binary: ${NGINX_SBIN}"
}

install_nginx_configuration() {
    local item

    if [[ "${is_upgrade}" == true ]]; then
        log_info 'Restoring preserved NGINX configuration...'
        rm -rf "${NGINX_PREFIX}/nginx.conf" "${NGINX_PREFIX}/certs" "${NGINX_PREFIX}/domains" "${NGINX_PREFIX}/public"
        cp -a "${NGINX_BACKUP_DIR}/nginx.conf" "${NGINX_PREFIX}/nginx.conf"

        for item in certs conf.d domains public; do
            [[ -e "${NGINX_BACKUP_DIR}/${item}" ]] || continue
            cp -a "${NGINX_BACKUP_DIR}/${item}" "${NGINX_PREFIX}/"
        done

        return 0
    fi

    log_info 'Installing default NGINX configuration...'
    rsync -a "${REPO_ROOT}/toolkit/conf/nginx/" "${NGINX_PREFIX}/"
    install -m 644 "${REPO_ROOT}/toolkit/conf/systemd/nginx.service" /etc/systemd/system/nginx.service
    systemctl daemon-reload
}

configure_and_start_nginx() {
    if ! id -u "${NGINX_USER}" >/dev/null 2>&1; then
        useradd -r -s /sbin/nologin "${NGINX_USER}"
        log_info "NGINX user created: ${NGINX_USER}"
    fi

    install -d -m 755 /var/cache/nginx /var/log/nginx "${NGINX_PREFIX}/certs"
    install_nginx_configuration

    apt-mark hold nginx nginx-debug || log_warn 'Could not hold NGINX packages'

    "${REPO_ROOT}/toolkit/security/setup-nginx-apparmor.sh" --load-only
    "${NGINX_SBIN}" -t
    systemctl enable nginx
    systemctl restart nginx

    "${REPO_ROOT}/toolkit/security/setup-nginx-apparmor.sh" --verify

    log_success "NGINX installed and started; version: ${NGINX_VERSION}"
}

setup_nginx_integrations() {
    log_info 'Setting up NGINX Cloudflare IP updates...'
    "${REPO_ROOT}/toolkit/service/setup-cloudflare-nginx.sh" || log_warn 'Cloudflare NGINX setup failed; rerun toolkit/service/setup-cloudflare-nginx.sh'

    log_info 'Setting up NGINX logrotate policy...'
    "${REPO_ROOT}/toolkit/service/setup-logrotate-nginx.sh" || log_warn 'NGINX logrotate setup failed; rerun toolkit/service/setup-logrotate-nginx.sh'
}

cleanup_build_dependencies() {
    log_info 'Installing runtime packages and removing build-only packages...'
    apt-get install -y --no-install-recommends "${RUNTIME_PACKAGES[@]}"

    if ((${#new_build_packages[@]} > 0)); then
        apt-get remove --purge -y "${new_build_packages[@]}" || log_warn 'Could not remove all build-only packages'
    else
        log_info 'All build packages were already installed; skipping build package removal'
    fi
}

# Run
main() (
    local force=false
    local is_upgrade=false
    local new_build_packages=()
    local build_root_dir nginx_version_output

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
    require_cmd apt-get apt-mark cp date dpkg-query id install mktemp mv nproc rm systemctl tar useradd

    if [[ ! "${NGINX_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid NGINX version: ${NGINX_VERSION}"
        exit 1
    fi

    build_root_dir="$(mktemp -d /tmp/build-nginx.XXXXXX)"
    trap 'rm -rf -- "${build_root_dir}"' EXIT

    prepare_existing_installation
    install_build_dependencies
    prepare_sources
    build_brotli
    build_quictls
    download_nginx
    build_and_install_nginx
    cleanup_build_dependencies
    configure_and_start_nginx
    setup_nginx_integrations
    nginx_version_output="$("${NGINX_SBIN}" -v 2>&1)"
    log_info "${nginx_version_output}"
    systemctl status nginx --no-pager
)

main "$@"
