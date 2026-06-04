#!/usr/bin/env bash
# Install or update shfmt from the latest mvdan/sh GitHub release.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

SHFMT_BIN="${SHFMT_BIN:-/usr/local/bin/shfmt}"
SHFMT_REPO="${SHFMT_REPO:-mvdan/sh}"
SHFMT_VERSION="${SHFMT_VERSION:-latest}"

# Functions
latest_shfmt_version() {
    curl -fsSL "https://api.github.com/repos/${SHFMT_REPO}/releases/latest" |
        jq -r '.tag_name' |
        sed 's/^v//'
}

shfmt_architecture() {
    case "$(detect_architecture)" in
    x86_64) printf 'amd64\n' ;;
    aarch64) printf 'arm64\n' ;;
    esac
}

install_shfmt() {
    local arch
    local version
    local url
    local tmp_file

    require_cmd curl install jq mktemp sed

    version="${SHFMT_VERSION}"
    if [[ "${version}" == "latest" ]]; then
        log_info "Resolving latest shfmt release..."
        version="$(latest_shfmt_version)"
    else
        version="${version#v}"
    fi

    if [[ -z "${version}" || "${version}" == "null" ]]; then
        log_error "Unable to resolve shfmt version."
        exit 1
    fi

    arch="$(shfmt_architecture)"
    url="https://github.com/${SHFMT_REPO}/releases/download/v${version}/shfmt_v${version}_linux_${arch}"
    tmp_file="$(mktemp)"
    trap 'rm -f "${tmp_file}"' EXIT

    log_info "Downloading shfmt v${version} (${arch})..."
    curl -fsSL "${url}" -o "${tmp_file}"

    log_info "Installing shfmt to ${SHFMT_BIN}..."
    install -m 755 "${tmp_file}" "${SHFMT_BIN}"

    log_success "shfmt installed: $(${SHFMT_BIN} --version)"
}

require_root
install_shfmt
