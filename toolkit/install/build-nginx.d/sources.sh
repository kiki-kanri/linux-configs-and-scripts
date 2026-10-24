#!/usr/bin/env bash

# shellcheck disable=SC2034

# Upstream sources and nginx configure module flags.

# Constants/Variables
readonly -a NGINX_MODULE_REPOS=(
    'ngx_brotli|https://github.com/google/ngx_brotli.git'
    'ngx_http_geoip2_module|https://github.com/leev/ngx_http_geoip2_module.git'
    'headers-more-nginx-module|https://github.com/openresty/headers-more-nginx-module.git'
    'zstd-nginx-module|https://github.com/tokers/zstd-nginx-module.git'
)

readonly -a NGINX_MODULE_CONFIGURE_ARGS=(
    --add-dynamic-module=../ngx_http_geoip2_module
    --add-module=../headers-more-nginx-module
    --add-module=../ngx_brotli
    --add-module=../zstd-nginx-module
)

readonly QUICTLS_REPO_URL='https://github.com/quictls/quictls.git'
