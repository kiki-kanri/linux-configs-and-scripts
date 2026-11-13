#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC2034

# Versions, sources, paths and packages for the nginx build.

# Constants/Variables
readonly DEFAULT_NGINX_VERSION='1.31.8'
readonly DEFAULT_OPENSSL_VERSION='4.1.0'
readonly BROTLI_REF='v1.2.1'
readonly MIN_CLANG_MAJOR=14

readonly NGINX_DOWNLOAD_URL='https://nginx.org/download'
readonly OPENSSL_DOWNLOAD_URL='https://github.com/openssl/openssl/releases/download'
readonly BROTLI_REPO_URL='https://github.com/google/brotli.git'

# Source-release keys from https://nginx.org/en/pgp_keys.html and https://openssl-library.org/source/; update on key rotation.
readonly NGINX_SIGNING_KEYS="${REPO_ROOT}/toolkit/conf/keys/nginx-source-signing.asc"
readonly OPENSSL_SIGNING_KEYS="${REPO_ROOT}/toolkit/conf/keys/openssl-source-signing.asc"

# Format: <directory>|<repository>|<tag or commit>|<static or dynamic>
readonly -a NGINX_MODULES=(
    'headers-more-nginx-module|https://github.com/openresty/headers-more-nginx-module.git|v0.41|static'
    'ngx_brotli|https://github.com/google/ngx_brotli.git|53e0fb55f250f48fe80c0ddbf6c0f7103cdbaae1|static'
    'ngx_http_geoip2_module|https://github.com/leev/ngx_http_geoip2_module.git|3.4|dynamic'
    'ngx_http_zstd_module|https://github.com/HanadaLee/ngx_http_zstd_module.git|0.1.2|static'
)

readonly NGINX_PREFIX='/etc/nginx'
readonly NGINX_BACKUP_DIR='/etc/nginx.bak'
readonly NGINX_SBIN='/usr/sbin/nginx'
readonly NGINX_MODULES_DIR='/usr/lib/nginx/modules'
readonly NGINX_BUILD_INFO='/usr/lib/nginx/build-info'
readonly NGINX_CACHE_DIR='/var/cache/nginx'
readonly NGINX_LOG_DIR='/var/log/nginx'
readonly NGINX_USER='nginx'
readonly NGINX_GROUP='nginx'
readonly NGINX_CONF_SRC="${REPO_ROOT}/toolkit/conf/nginx"
readonly NGINX_SERVICE_SRC="${REPO_ROOT}/toolkit/conf/systemd/nginx.service"
readonly NGINX_SERVICE_DEST='/etc/systemd/system/nginx.service'

# Files shipped with the nginx source and refreshed on every install.
readonly -a NGINX_UPSTREAM_CONF_FILES=(
    fastcgi.conf
    fastcgi_params
    mime.types
    scgi_params
    uwsgi_params
)

# Removed after the build, with their dependencies, when this run installed them.
readonly -a BUILD_ONLY_PACKAGES=(
    clang
    cmake
    libmaxminddb-dev
    libpcre2-dev
    libzstd-dev
    lld
    llvm
    ninja-build
    zlib1g-dev
)

# Kept installed after the build.
readonly -a BUILD_TOOLS=(
    binutils
    curl
    git
    gpg
    gpgv
    make
    perl
    tar
)

readonly -a RUNTIME_PACKAGES=(
    libmaxminddb0
    libpcre2-8-0
    zlib1g
)
