#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

# Build and install nginx with HTTP/3 on static OpenSSL, Brotli, zstd, GeoIP2 and headers-more.
# Options: -f skips the upgrade confirmation; -v <version> selects the nginx version;
# --build-only builds and keeps the build directory without touching the installed nginx.

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../../libs/common.sh"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/flags.sh"

# Constants/Variables
readonly BUILD_PARENT_DIR='/var/tmp'

# Functions
require_supported_release() {
    local ID VERSION_ID PRETTY_NAME

    source /etc/os-release
    case "${ID}:${VERSION_ID}" in
    debian:12 | debian:13 | ubuntu:24.04 | ubuntu:26.04 | ubuntu:26.10) ;;
    *)
        log_error "Unsupported operating system release: ${PRETTY_NAME}"
        exit 1
        ;;
    esac
}

cleanup_build_dir() {
    if [[ "${keep_build_dir}" == true ]]; then
        log_info "Build directory kept: ${build_dir}"
        return 0
    fi

    safe_rm_under_root "${BUILD_PARENT_DIR}" "${build_dir}"
}

prepare_existing_installation() {
    local backup_timestamp

    if [[ -f "${NGINX_PREFIX}/nginx.conf" ]]; then
        is_upgrade=true
        log_info "Existing NGINX installation detected: ${NGINX_PREFIX}"
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
        mv -- "${NGINX_BACKUP_DIR}" "${NGINX_BACKUP_DIR}.${backup_timestamp}"
    fi

    log_info "Backing up NGINX configuration to: ${NGINX_BACKUP_DIR}..."
    cp -a -- "${NGINX_PREFIX}" "${NGINX_BACKUP_DIR}"
}

list_installed_packages() {
    dpkg-query -W -f='${db:Status-Status} ${Package}\n' | awk '$1 == "installed" { print $2 }' | LC_ALL=C sort -u
}

# Prints the packages from stdin that were not installed before this run.
filter_new_packages() {
    LC_ALL=C comm -13 <(printf '%s\n' "${preinstalled_packages[@]}") <(LC_ALL=C sort -u)
}

install_build_dependencies() {
    local clang_version

    log_info 'Installing NGINX build dependencies...'
    apt-get update
    mapfile -t preinstalled_packages < <(list_installed_packages)
    apt-get install -y --no-install-recommends "${BUILD_ONLY_PACKAGES[@]}" "${BUILD_TOOLS[@]}"

    clang_version="$(clang -dumpversion)"
    clang_major="${clang_version%%.*}"
    if ((clang_major < MIN_CLANG_MAJOR)); then
        log_error "Clang ${MIN_CLANG_MAJOR} or newer is required; found: ${clang_version}"
        exit 1
    fi

    build_info+=("compiler=clang ${clang_version}")
}

fetch_verified_archive() {
    local url="$1"
    local signing_keys="$2"
    local archive="${build_dir}/${url##*/}"
    local gpg_home="${build_dir}/gnupg"

    log_info "Downloading and verifying: ${url}..."
    curl -fsSL -o "${archive}" "${url}"
    curl -fsSL -o "${archive}.asc" "${url}.asc"

    install -d -m 700 "${gpg_home}"
    gpg --batch --quiet --yes --homedir "${gpg_home}" --dearmor --output "${gpg_home}/trusted.gpg" "${signing_keys}"
    gpgv --homedir "${gpg_home}" --keyring "${gpg_home}/trusted.gpg" "${archive}.asc" "${archive}"
    tar -xf "${archive}" -C "${build_dir}"
}

fetch_git_ref() {
    local name="$1"
    local repo_url="$2"
    local ref="$3"
    local dest="$4"
    local commit

    log_info "Fetching ${name}: ${ref}..."
    git init -q "${dest}"
    git -C "${dest}" fetch -q --depth=1 "${repo_url}" "${ref}"
    git -C "${dest}" checkout -q --detach FETCH_HEAD
    commit="$(git -C "${dest}" rev-parse HEAD)"
    build_info+=("${name}=${ref} ${commit}")
}

fetch_sources() {
    local module name repo_url ref

    fetch_verified_archive "${NGINX_DOWNLOAD_URL}/nginx-${nginx_version}.tar.gz" "${NGINX_SIGNING_KEYS}"
    fetch_verified_archive "${OPENSSL_DOWNLOAD_URL}/openssl-${openssl_version}/openssl-${openssl_version}.tar.gz" "${OPENSSL_SIGNING_KEYS}"

    for module in "${NGINX_MODULES[@]}"; do
        IFS='|' read -r name repo_url ref _ <<<"${module}"
        fetch_git_ref "${name}" "${repo_url}" "${ref}" "${build_dir}/${name}"
    done

    # ngx_brotli expects the Brotli library at deps/brotli and its build output at deps/brotli/out.
    fetch_git_ref brotli "${BROTLI_REPO_URL}" "${BROTLI_REF}" "${build_dir}/ngx_brotli/deps/brotli"
}

build_brotli() {
    local src_dir="${build_dir}/ngx_brotli/deps/brotli"

    log_info 'Building Brotli...'
    CC=clang cmake \
        -S "${src_dir}" \
        -B "${src_dir}/out" \
        -G Ninja \
        -DBROTLI_BUILD_TOOLS=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_FLAGS="${BASE_CFLAGS[*]}" \
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON

    ninja -C "${src_dir}/out" brotlienc brotlicommon
}

build_nginx() {
    local src_dir="${build_dir}/nginx-${nginx_version}"
    local module name kind nginx_build_output
    local -a configure_args=("${NGINX_CONFIGURE_OPTIONS[@]}")

    for module in "${NGINX_MODULES[@]}"; do
        IFS='|' read -r name _ _ kind <<<"${module}"
        case "${kind}" in
        static) configure_args+=("--add-module=${build_dir}/${name}") ;;
        dynamic) configure_args+=("--add-dynamic-module=${build_dir}/${name}") ;;
        esac
    done

    configure_args+=(
        "--with-openssl=${build_dir}/openssl-${openssl_version}"
        "--with-openssl-opt=${OPENSSL_OPTIONS[*]}"
        "--with-cc-opt=${NGINX_CFLAGS[*]}"
        "--with-ld-opt=${NGINX_LDFLAGS[*]}"
    )

    log_info "Building NGINX ${nginx_version} with OpenSSL ${openssl_version}..."
    (
        cd "${src_dir}"
        # nginx builds OpenSSL from its own Makefile, which inherits CC from the environment.
        export CC=clang
        ./configure "${configure_args[@]}"
        make -j"$(nproc)"
    )

    strip --strip-all "${src_dir}/objs/nginx"
    strip --strip-unneeded "${src_dir}"/objs/*.so

    nginx_build_output="$("${src_dir}/objs/nginx" -V 2>&1)"
    if [[ "${nginx_build_output}" != *"built with OpenSSL ${openssl_version} "* ]]; then
        log_error "NGINX is not linked with OpenSSL ${openssl_version}"
        printf '%s\n' "${nginx_build_output}" >&2
        exit 1
    fi

    # PIE comes from the Clang default, not from explicit flags.
    if [[ "$(readelf -h "${src_dir}/objs/nginx")" != *'DYN (Position-Independent Executable file)'* ]]; then
        log_error 'NGINX binary is not a position-independent executable'
        exit 1
    fi

    log_success "NGINX built: ${src_dir}/objs/nginx"
}

cleanup_build_dependencies() {
    local -a new_build_packages orphaned_packages

    log_info 'Installing runtime packages and removing build-only packages...'
    apt-get install -y --no-install-recommends "${RUNTIME_PACKAGES[@]}"

    mapfile -t new_build_packages < <(printf '%s\n' "${BUILD_ONLY_PACKAGES[@]}" | filter_new_packages)
    ((${#new_build_packages[@]} > 0)) || return 0
    apt-get remove --purge -y "${new_build_packages[@]}" || log_warn 'Could not remove all build-only packages'

    # Metapackages leave their versioned dependencies behind; remove only orphans that this run installed.
    mapfile -t orphaned_packages < <(apt-get -s autoremove | awk '$1 == "Remv" { print $2 }' | filter_new_packages)
    ((${#orphaned_packages[@]} > 0)) || return 0
    apt-get remove --purge -y "${orphaned_packages[@]}" || log_warn 'Could not remove all build-only dependencies'
}

# Keeps the previous file as <dest>.old and replaces <dest> atomically.
replace_binary() {
    local src="$1"
    local dest="$2"

    [[ ! -f "${dest}" ]] || cp -a -- "${dest}" "${dest}.old"
    install -m 755 "${src}" "${dest}.new"
    mv -f -- "${dest}.new" "${dest}"
}

install_nginx() {
    local src_dir="${build_dir}/nginx-${nginx_version}"
    local module file

    log_info 'Installing NGINX...'
    if ! id -u "${NGINX_USER}" >/dev/null 2>&1; then
        useradd --system --user-group --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin "${NGINX_USER}"
        log_info "NGINX user created: ${NGINX_USER}"
    fi

    install -d -m 755 "${NGINX_PREFIX}" "${NGINX_PREFIX}/certs" "${NGINX_MODULES_DIR}" "${NGINX_CACHE_DIR}" "${NGINX_LOG_DIR}"

    replace_binary "${src_dir}/objs/nginx" "${NGINX_SBIN}"
    for module in "${src_dir}"/objs/*.so; do
        replace_binary "${module}" "${NGINX_MODULES_DIR}/${module##*/}"
    done

    for file in "${NGINX_UPSTREAM_CONF_FILES[@]}"; do
        install -m 644 "${src_dir}/conf/${file}" "${NGINX_PREFIX}/${file}"
    done

    install_file "${NGINX_SERVICE_SRC}" "${NGINX_SERVICE_DEST}" 644
    systemctl daemon-reload
    apt-mark hold nginx >/dev/null || log_warn 'Could not hold the distribution NGINX package'
}

# Fresh installs take the repo configuration as is; upgrades review each changed file.
sync_configuration() {
    if [[ "${is_upgrade}" == true ]]; then
        "${SCRIPT_DIR}/sync-conf.sh"
    else
        "${SCRIPT_DIR}/sync-conf.sh" -y
    fi
}

write_build_info() {
    build_info=(
        "built_at=$(date --iso-8601=seconds)"
        "nginx=${nginx_version}"
        "openssl=${openssl_version}"
        "${build_info[@]}"
    )
    printf '%s\n' "${build_info[@]}" >"${NGINX_BUILD_INFO}"
}

start_nginx() {
    "${REPO_ROOT}/toolkit/security/setup-nginx-apparmor.sh" --load-only

    if ! "${NGINX_SBIN}" -t; then
        log_error 'NGINX configuration test failed; the running service was not restarted'
        log_error "Fix ${NGINX_PREFIX}, then run nginx -t and systemctl restart nginx, or rerun this script"
        exit 1
    fi

    systemctl enable nginx
    systemctl restart nginx
    "${REPO_ROOT}/toolkit/security/setup-nginx-apparmor.sh" --verify
}

setup_nginx_integrations() {
    log_info 'Setting up NGINX Cloudflare IP updates...'
    "${REPO_ROOT}/toolkit/service/setup-cloudflare-nginx.sh" || log_warn 'Cloudflare NGINX setup failed; rerun toolkit/service/setup-cloudflare-nginx.sh'

    log_info 'Setting up NGINX logrotate policy...'
    "${REPO_ROOT}/toolkit/service/setup-logrotate-nginx.sh" || log_warn 'NGINX logrotate setup failed; rerun toolkit/service/setup-logrotate-nginx.sh'
}

# Run
main() (
    local force=false
    local build_only=false
    local is_upgrade=false
    local keep_build_dir=false
    local nginx_version="${NGINX_VERSION:-${DEFAULT_NGINX_VERSION}}"
    local openssl_version="${OPENSSL_VERSION:-${DEFAULT_OPENSSL_VERSION}}"
    local arch build_dir clang_major
    local -a preinstalled_packages=()
    local -a build_info=()

    while (($# > 0)); do
        case "$1" in
        -f)
            force=true
            shift
            ;;
        -v)
            [[ -n "${2:-}" ]] || {
                log_error "Missing value for option: $1"
                exit 2
            }
            nginx_version="$2"
            shift 2
            ;;
        --build-only)
            build_only=true
            shift
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 2
            ;;
        esac
    done

    require_root
    require_supported_release
    require_cmd apt-get apt-mark cmp cp date diff dpkg-query find id install mktemp mv nproc sort systemctl useradd

    if [[ ! "${nginx_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! "${openssl_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid version; NGINX: ${nginx_version}; OpenSSL: ${openssl_version}"
        exit 1
    fi

    arch="$(detect_architecture)"

    [[ "${build_only}" == true ]] || prepare_existing_installation

    build_dir="$(mktemp -d "${BUILD_PARENT_DIR}/build-nginx.XXXXXX")"
    trap cleanup_build_dir EXIT

    install_build_dependencies
    set_build_flags "${arch}" "${clang_major}"
    fetch_sources
    build_brotli
    build_nginx
    cleanup_build_dependencies

    if [[ "${build_only}" == true ]]; then
        keep_build_dir=true
        return 0
    fi

    install_nginx
    sync_configuration
    write_build_info
    start_nginx
    setup_nginx_integrations

    log_success "NGINX installed and started: $("${NGINX_SBIN}" -v 2>&1)"
    systemctl status nginx --no-pager
)

main "$@"
