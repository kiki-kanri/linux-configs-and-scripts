#!/usr/bin/env bash
# Install or update shfmt from the latest mvdan/sh GitHub release.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

SHFMT_BIN="${SHFMT_BIN:-/usr/local/bin/shfmt}"
SHFMT_REPO="${SHFMT_REPO:-mvdan/sh}"
SHFMT_VERSION="${SHFMT_VERSION:-latest}"
SHFMT_FALLBACK_VERSION="${SHFMT_FALLBACK_VERSION:-3.13.1}"
SHFMT_GITHUB_API_URL="${SHFMT_GITHUB_API_URL:-https://api.github.com/repos/${SHFMT_REPO}}"
SHFMT_DOWNLOAD_BASE_URL="${SHFMT_DOWNLOAD_BASE_URL:-https://github.com/${SHFMT_REPO}/releases/download}"

curl_args=(
    --fail
    --location
    --show-error
    --silent
    --connect-timeout 15
    --max-time 180
    --retry 5
    --retry-delay 2
    --retry-max-time 300
)

tmp_file=""

curl_fetch() {
    curl "${curl_args[@]}" "$@"
}

latest_shfmt_version() {
    curl_fetch "${SHFMT_GITHUB_API_URL}/releases/latest" |
        jq -r '.tag_name' |
        sed 's/^v//'
}

resolve_shfmt_version() {
    local version="${SHFMT_VERSION}"

    if [[ "${version}" != "latest" ]]; then
        printf '%s\n' "${version#v}"
        return 0
    fi

    if version="$(latest_shfmt_version)" && [[ -n "${version}" && "${version}" != "null" ]]; then
        printf '%s\n' "${version}"
        return 0
    fi

    log_warn "Unable to resolve latest shfmt release; falling back to v${SHFMT_FALLBACK_VERSION}."
    printf '%s\n' "${SHFMT_FALLBACK_VERSION#v}"
}

shfmt_architecture() {
    case "$(detect_architecture)" in
    x86_64) printf 'amd64\n' ;;
    aarch64) printf 'arm64\n' ;;
    esac
}

cleanup() {
    [[ -z "${tmp_file}" ]] || rm -f -- "${tmp_file}"
}

install_shfmt() {
    local arch
    local version
    local url

    require_cmd curl install jq mktemp sed

    [[ "${SHFMT_VERSION}" != "latest" ]] || log_info "Resolving latest shfmt release..."
    version="$(resolve_shfmt_version)"
    if [[ -z "${version}" || "${version}" == "null" ]]; then
        log_error "Unable to resolve shfmt version."
        exit 1
    fi

    arch="$(shfmt_architecture)"
    url="${SHFMT_DOWNLOAD_BASE_URL}/v${version}/shfmt_v${version}_linux_${arch}"
    tmp_file="$(mktemp)"
    trap cleanup EXIT

    log_info "Downloading shfmt v${version} (${arch})..."
    curl_fetch "${url}" -o "${tmp_file}"

    log_info "Installing shfmt to ${SHFMT_BIN}..."
    install -m 755 "${tmp_file}" "${SHFMT_BIN}"

    log_success "shfmt installed: $(${SHFMT_BIN} --version)"
}

require_root
install_shfmt
