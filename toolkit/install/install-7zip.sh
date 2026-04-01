#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# install-7zip.sh — Install 7-Zip (7zz/7zzs) from 7-zip.org
#
# Supports: x86_64 (amd64), aarch64 (arm64)
# Homepage: https://www.7-zip.org/

set -Eeuo pipefail

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

# Probe for the latest version by checking which 4-digit version numbers exist.
# Versions go: 2408, 2501, 2600 ... up to a reasonable ceiling.
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

    # Scrape the latest version from the download page.
    # The top-most Linux entry is always the latest version.
    local html version
    html="$(curl -fsSL "${BASE_URL}/download.html")" || return 1

    case "${arch}" in
    x86_64) version="$(printf '%s\n' "${html}" | grep -oP '7z[0-9]+-linux-x64\.tar\.xz' | head -1)" ;;
    aarch64) version="$(printf '%s\n' "${html}" | grep -oP '7z[0-9]+-linux-arm64\.tar\.xz' | head -1)" ;;
    esac

    version="${version#7z}"      # strip leading "7z"
    version="${version%-linux*}" # strip trailing "-linux-..."

    if [[ -z "${version}" ]]; then
        echo "ERROR: Could not detect latest 7-Zip version for ${arch}" >&2
        return 1
    fi

    printf '%s\n' "${version}"
}

do_install() {
    local arch version filename url tarball

    arch="$(detect_architecture)"
    version="$(fetch_latest_version "${arch}")"
    log_info "Latest 7-Zip version for ${arch}: ${version}"

    local arch_url
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
        return 1
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
}

main() {
    local skip_confirm=false

    while getopts 'y' opt; do
        case $opt in
        y) skip_confirm=true ;;
        *) ;;
        esac
    done
    shift $((OPTIND - 1))

    if [[ -x "${BIN_PATH}" ]]; then
        local installed_version
        installed_version="$("${BIN_PATH}" -v 2>/dev/null | head -1 || echo "unknown")"
        log_info "7-Zip is already installed at ${BIN_PATH} (${installed_version})."

        if [[ "$skip_confirm" == false ]]; then
            confirm "Re-install / upgrade?" --default=no || exit 0
        else
            log_info "Force re-install enabled via -y flag."
        fi
    fi

    do_install
}

main "$@"
