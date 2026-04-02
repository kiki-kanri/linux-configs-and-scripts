#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# install-from-url.sh — Download a binary and install it to a path
#
# Usage:
#   install_from_url "https://example.com/bin" "/usr/local/bin/mytool" "mytool"
#   install_from_url "https://example.com/bin" "/usr/local/bin/mytool" "mytool" "amd64"
#
# The 4th arg optionally specifies the expected architecture in the URL
# (e.g. "amd64" -> replaces "{ARCH}" in the URL).
# If not specified, the current machine's architecture is used.
#
# The 3rd arg is used for checksum verification (optional SHA256).
# If a file <SCRIPT_DIR>/<name>.sha256 exists, it will be used.
#
# Requires: curl, sha256sum (optional for verification)

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

source "${LIB_DIR}/log.sh"

_install_from_url() {
    local url="$1"
    local dest="$2"
    local name="$3"
    local arch="${4:-$(detect_architecture 2>/dev/null || echo 'unknown')}"
    local tmpfile
    tmpfile="$(mktemp)"

    # Replace {ARCH} placeholder in URL
    local actual_url="${url//\{ARCH\}/${arch}}"

    log_info "Downloading ${name} from ${actual_url}..."

    if ! curl -fsSL --output "${tmpfile}" "${actual_url}"; then
        log_error "Download failed: ${actual_url}"
        rm -f "${tmpfile}"
        return 1
    fi

    # Optional SHA256 verification
    local checksum_file="${SCRIPT_DIR:-/dev/null}/${name}.sha256"
    if [[ -f "${checksum_file}" ]]; then
        log_info "Verifying checksum..."
        if ! sha256sum --check "${checksum_file}" 2>/dev/null; then
            log_error "Checksum verification failed for ${name}."
            rm -f "${tmpfile}"
            return 1
        fi
        log_success "Checksum verified."
    fi

    # Ensure destination directory exists
    local dest_dir
    dest_dir="$(dirname "${dest}")"
    if [[ ! -d "${dest_dir}" ]]; then
        mkdir -p "${dest_dir}"
    fi

    mv -f "${tmpfile}" "${dest}"
    chmod +x "${dest}"

    log_success "Installed ${name} to ${dest}"
}

# Wrapper that detects architecture if not provided
install_from_url() {
    local url="$1"
    local dest="$2"
    local name="$3"
    local arch="${4:-}"

    if [[ -z "${arch}" ]]; then
        arch="$(detect_architecture 2>/dev/null)" || arch="unknown"
    fi

    _install_from_url "${url}" "${dest}" "${name}" "${arch}"
}
