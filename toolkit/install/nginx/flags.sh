#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC2034

# Compiler, linker and configure options for the nginx build.

# Constants/Variables
readonly -a NGINX_CONFIGURE_OPTIONS=(
    --prefix="${NGINX_PREFIX}"
    --sbin-path="${NGINX_SBIN}"
    --modules-path="${NGINX_MODULES_DIR}"
    --conf-path="${NGINX_PREFIX}/nginx.conf"
    --error-log-path="${NGINX_LOG_DIR}/error.log"
    --http-log-path="${NGINX_LOG_DIR}/access.log"
    --pid-path=/run/nginx.pid
    --lock-path=/run/nginx.lock
    --http-client-body-temp-path="${NGINX_CACHE_DIR}/client_temp"
    --http-fastcgi-temp-path="${NGINX_CACHE_DIR}/fastcgi_temp"
    --http-proxy-temp-path="${NGINX_CACHE_DIR}/proxy_temp"
    --http-scgi-temp-path="${NGINX_CACHE_DIR}/scgi_temp"
    --http-uwsgi-temp-path="${NGINX_CACHE_DIR}/uwsgi_temp"
    --user="${NGINX_USER}"
    --group="${NGINX_GROUP}"
    --with-compat
    --with-http_addition_module
    --with-http_auth_request_module
    --with-http_dav_module
    --with-http_flv_module
    --with-http_gunzip_module
    --with-http_gzip_static_module
    --with-http_mp4_module
    --with-http_random_index_module
    --with-http_realip_module
    --with-http_secure_link_module
    --with-http_slice_module
    --with-http_ssl_module
    --with-http_stub_status_module
    --with-http_sub_module
    --with-http_v2_module
    --with-http_v3_module
    --with-mail
    --with-mail_ssl_module
    --with-pcre-jit
    --with-stream
    --with-stream_realip_module
    --with-stream_ssl_module
    --with-stream_ssl_preread_module
    --with-threads
    --without-poll_module
    --without-select_module
)

# Functions
# Sets BASE_CFLAGS, NGINX_CFLAGS, NGINX_LDFLAGS and OPENSSL_OPTIONS for the target architecture and Clang major version.
set_build_flags() {
    local arch="$1"
    local clang_major="$2"
    local -a arch_flags

    case "${arch}" in
    x86_64) arch_flags=(-march=native -fcf-protection=full -fstack-clash-protection) ;;
    aarch64)
        arch_flags=(-mcpu=native -mbranch-protection=standard)
        # Clang 18 added AArch64 stack clash protection; older versions warn, which nginx -Werror turns into a failure.
        ((clang_major < 18)) || arch_flags+=(-fstack-clash-protection)
        ;;
    esac

    BASE_CFLAGS=(
        -O3
        "${arch_flags[@]}"
        -U_FORTIFY_SOURCE
        -D_FORTIFY_SOURCE=3
        -fstack-protector-strong
        -ffunction-sections
        -fdata-sections
    )

    # No -fPIE/-pie: these options also reach dynamic modules and override the -fPIC nginx adds for them.
    # Distribution Clang builds PIE executables by default.
    NGINX_CFLAGS=(
        "${BASE_CFLAGS[@]}"
        -flto=thin
    )

    NGINX_LDFLAGS=(
        -fuse-ld=lld
        -flto=thin
        '-Wl,-O2'
        '-Wl,--as-needed'
        '-Wl,--gc-sections'
        '-Wl,-z,relro'
        '-Wl,-z,now'
        '-Wl,-z,noexecstack'
    )

    # nginx adds no-shared and no-threads; unknown dash options are passed to the compiler.
    OPENSSL_OPTIONS=(
        no-apps
        no-docs
        no-legacy
        no-tests
        enable-ktls
        --openssldir=/usr/lib/ssl
        "${BASE_CFLAGS[@]}"
        -fPIC
    )
}
