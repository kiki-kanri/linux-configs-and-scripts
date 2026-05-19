#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# Install or update the official 7-Zip Linux binaries (7zz and 7zzs).

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

INSTALL_DIR="/opt/7zip"
BIN_PATH="/usr/local/bin/7zz"
BIN_PATH_S="/usr/local/bin/7zzs"
BASE_URL="https://www.7-zip.org"
version=""
tarball=""
tmpdir=""

archive_arch() {
    case "$1" in
    x86_64) printf 'x64\n' ;;
    aarch64) printf 'arm64\n' ;;
    *)
        log_error "Unsupported architecture: $1"
        return 1
        ;;
    esac
}

fetch_latest_version() {
    local arch_url="$1"
    local html filename

    log_info "Detecting latest 7-Zip version for linux-${arch_url}..." >&2
    html="$(curl -fsSL "${BASE_URL}/download.html")" || {
        log_error "Could not fetch ${BASE_URL}/download.html"
        return 1
    }

    filename="$(awk -v arch="${arch_url}" '
        match($0, "7z[0-9]+-linux-" arch "[.]tar[.]xz") {
            print substr($0, RSTART, RLENGTH)
            exit
        }
    ' <<<"${html}")"

    [[ -n "${filename}" ]] || {
        log_error "Could not detect latest 7-Zip version for linux-${arch_url}."
        return 1
    }

    filename="${filename#7z}"
    printf '%s\n' "${filename%-linux*}"
}

cleanup() {
    [[ -z "${tarball}" ]] || rm -f "${tarball}"
    [[ -z "${tmpdir}" ]] || rm -rf "${tmpdir}"
}

set_install_permissions() {
    find "${INSTALL_DIR}" -type d -exec chmod 755 {} +
    find "${INSTALL_DIR}" -type f -exec chmod 644 {} +
    chmod 755 "${INSTALL_DIR}/7zz" "${INSTALL_DIR}/7zzs"
}

warn_if_bin_not_in_path() {
    case ":${PATH}:" in
    *:/usr/local/bin:*) return 0 ;;
    esac

    log_warn "/usr/local/bin is not in PATH for this shell; run with ${BIN_PATH} or update PATH."
}

while (($# > 0)); do
    case "$1" in
    -v)
        [[ -n "${2:-}" ]] || {
            log_error "-v requires a version number."
            exit 1
        }
        version="$2"
        shift 2
        ;;
    -*)
        log_error "Unknown option: $1"
        exit 1
        ;;
    *)
        log_error "Unexpected argument: $1"
        exit 1
        ;;
    esac
done

require_root
require_cmd curl tar find chmod install cp ln rm mktemp awk

arch="$(detect_architecture)"
arch_url="$(archive_arch "${arch}")"
version="${version:-$(fetch_latest_version "${arch_url}")}"
filename="7z${version}-linux-${arch_url}.tar.xz"
url="${BASE_URL}/a/${filename}"
tarball="$(mktemp)"
tmpdir="$(mktemp -d)"
trap cleanup EXIT

if [[ -e "${INSTALL_DIR}" || -e "${BIN_PATH}" || -e "${BIN_PATH_S}" ]]; then
    log_info "Existing 7-Zip install detected; replacing it."
fi

log_info "Downloading ${url}..."
curl -fsSL --output "${tarball}" "${url}"

log_info "Extracting archive..."
tar -xf "${tarball}" -C "${tmpdir}"
[[ -x "${tmpdir}/7zz" && -x "${tmpdir}/7zzs" ]] || {
    log_error "Archive does not contain executable 7zz and 7zzs binaries."
    exit 1
}

log_info "Installing to ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}"
install -d -m 755 "${INSTALL_DIR}"
cp -a "${tmpdir}/." "${INSTALL_DIR}/"
set_install_permissions
ln -sfn "${INSTALL_DIR}/7zz" "${BIN_PATH}"
ln -sfn "${INSTALL_DIR}/7zzs" "${BIN_PATH_S}"

log_success "7-Zip ${version} (${arch}) installed."
log_info "Binary: ${BIN_PATH}"
log_info "Standalone binary: ${BIN_PATH_S}"
warn_if_bin_not_in_path
