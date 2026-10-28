#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC2034

# Compiler, linker and configure flags for build-nginx.sh.

# Constants/Variables
readonly -a BROTLI_CFLAGS=(
    -U_FORTIFY_SOURCE
    -D_FORTIFY_SOURCE=2
    -DNDEBUG
    -fdata-sections
    -ffunction-sections
    -fomit-frame-pointer
    -fPIC
    -fstack-clash-protection
    -fstack-protector-strong
    -fstrict-aliasing
    -march=native
    -O3
)

readonly -a NGINX_CFLAGS=(
    -U_FORTIFY_SOURCE
    -D_FORTIFY_SOURCE=2
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

readonly -a NGINX_LDFLAGS=(
    -flto=thin
    -fuse-ld=lld
    -L"${QUICTLS_DIR}/build"
    -ldl
    -lpthread
    '-Wl,--as-needed'
    '-Wl,--gc-sections'
    '-Wl,-E'
    '-Wl,-O2'
    "-Wl,-rpath,${QUICTLS_DIR}/build"
    '-Wl,-z,noexecstack'
    '-Wl,-z,now'
    '-Wl,-z,relro'
)

readonly -a NGINX_CONFIGURE_ARGS=(
    --add-dynamic-module=../ngx_http_geoip2_module
    --add-module=../headers-more-nginx-module
    --add-module=../ngx_brotli
    --add-module=../zstd-nginx-module
    --conf-path="${NGINX_PREFIX}/nginx.conf"
    --error-log-path=/var/log/nginx/error.log
    --group="${NGINX_GROUP}"
    --http-client-body-temp-path=/var/cache/nginx/client_temp
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp
    --http-log-path=/var/log/nginx/access.log
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp
    --lock-path=/run/nginx.lock
    --modules-path="${NGINX_MODULES_DIR}"
    --pid-path=/run/nginx.pid
    --prefix="${NGINX_PREFIX}"
    --sbin-path="${NGINX_SBIN}"
    --user="${NGINX_USER}"
    --with-cc-opt="${NGINX_CFLAGS[*]}"
    --with-compat
    --with-file-aio
    --with-http_addition_module
    --with-http_auth_request_module
    --with-http_dav_module
    --with-http_degradation_module
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
    --with-ld-opt="${NGINX_LDFLAGS[*]}"
    --with-mail
    --with-mail_ssl_module
    --without-poll_module
    --without-select_module
    --with-pcre-jit
    --with-stream
    --with-stream_geoip_module=dynamic
    --with-stream_realip_module
    --with-stream_ssl_module
    --with-stream_ssl_preread_module
    --with-threads
)

readonly -a QUICTLS_CFLAGS=(
    -U_FORTIFY_SOURCE
    -D_FORTIFY_SOURCE=2
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

readonly -a QUICTLS_LDFLAGS=(
    '-Wl,-z,noexecstack'
    '-Wl,-z,now'
    '-Wl,-z,relro'
)
