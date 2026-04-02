#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# install-7zip.sh — Install 7-Zip (7zz/7zzs) from 7-zip.org

set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root
require_cmd curl

INSTALL_DIR="/opt/7zip"
BIN_PATH="/usr/local/bin/7zz"
BIN_PATH_S="/usr/local/bin/7zzs"
BASE_URL="https://www.7-zip.org"

fetch_latest_version() {
    local arch="$1"

    case "${arch}" in
    x86_64) ;;
    aarch64) ;;
    *)
        echo "unsupported" >&2
        return 1
        ;;
    esac

    local html version
    html="$(curl -fsSL "${BASE_URL}/download.html")" || return 1

    case "${arch}" in
    x86_64) version="$(printf '%s\n' "${html}" | grep -oP '7z[0-9]+-linux-x64\.tar\.xz' | head -1)" ;;
    aarch64) version="$(printf '%s\n' "${html}" | grep -oP '7z[0-9]+-linux-arm64\.tar\.xz' | head -1)" ;;
    esac

    version="${version#7z}"
    version="${version%-linux*}"

    if [[ -z "${version}" ]]; then
        echo "ERROR: Could not detect latest 7-Zip version for ${arch}" >&2
        return 1
    fi

    printf '%s\n' "${version}"
}

# ── install ──────────────────────────────────────────────────────────────────

arch="$(detect_architecture)"
version="$(fetch_latest_version "${arch}")"
log_info "Latest 7-Zip version for ${arch}: ${version}"

case "${arch}" in
x86_64) arch_url="x64" ;;
aarch64) arch_url="arm64" ;;
esac

filename="7z${version}-linux-${arch_url}.tar.xz"
url="${BASE_URL}/a/${filename}"
tarball="$(mktemp)"

log_info "Downloading ${url}..."
if ! curl -fsSL --output "${tarball}" "${url}"; then
    log_error "Download failed: ${url}"
    rm -f "${tarball}"
    exit 1
fi

log_info "Installing to ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
tar -xf "${tarball}" -C "${INSTALL_DIR}"
rm -f "${tarball}"

rm -f "${BIN_PATH}" "${BIN_PATH_S}"
ln -s "${INSTALL_DIR}/7zz" "${BIN_PATH}"
ln -s "${INSTALL_DIR}/7zzs" "${BIN_PATH_S}"

log_success "7-Zip ${version} (${arch}) installed to ${INSTALL_DIR}"
log_info "Symlinked: ${BIN_PATH} and ${BIN_PATH_S}"
