#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC2034

# Paths and version defaults for build-nginx.sh.

# Constants/Variables
NGINX_VERSION="${NGINX_VERSION:-1.30.6}"
readonly BROTLI_VERSION="${BROTLI_VERSION:-1.2.1}"
readonly QUICTLS_DIR='/opt/quictls-for-nginx'
readonly NGINX_BACKUP_DIR='/etc/nginx.bak'
readonly NGINX_USER='nginx'
readonly NGINX_GROUP='nginx'
readonly NGINX_PREFIX='/etc/nginx'
readonly NGINX_MODULES_DIR='/usr/lib/nginx/modules'
readonly NGINX_SBIN='/usr/sbin/nginx'
# Source-release maintainer keys from https://nginx.org/en/pgp_keys.html; update on key rotation
readonly NGINX_SIGNING_KEYS="${REPO_ROOT}/toolkit/conf/keys/nginx-source-signing.asc"
