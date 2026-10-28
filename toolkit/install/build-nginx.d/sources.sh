#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC2034

# Upstream sources for build-nginx.sh.

# Constants/Variables
readonly NGINX_DOWNLOAD_URL='https://nginx.org/download'
readonly -a NGINX_MODULE_REPOS=(
    'ngx_brotli|https://github.com/google/ngx_brotli.git'
    'ngx_http_geoip2_module|https://github.com/leev/ngx_http_geoip2_module.git'
    'headers-more-nginx-module|https://github.com/openresty/headers-more-nginx-module.git'
    'zstd-nginx-module|https://github.com/tokers/zstd-nginx-module.git'
)

readonly QUICTLS_REPO_URL='https://github.com/quictls/quictls.git'
