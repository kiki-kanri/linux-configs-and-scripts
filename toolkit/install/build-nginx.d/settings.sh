#!/usr/bin/env bash
# Paths and version defaults for build-nginx.sh.
# shellcheck disable=SC2034

NGINX_VERSION="${NGINX_VERSION:-1.30.3}"
TMP_DIR="/tmp/build-nginx"
QUICTLS_DIR="/opt/quictls-for-nginx"
NGINX_BACKUP_DIR="/etc/nginx.bak"
NGINX_USER="nginx"
NGINX_GROUP="nginx"
NGINX_PREFIX="/etc/nginx"
NGINX_MODULES_DIR="/usr/lib/nginx/modules"
NGINX_SBIN="/usr/sbin/nginx"
