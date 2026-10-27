#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly RELEASE_API='https://api.github.com/repos/mvdan/sh/releases/latest'
readonly SHFMT_BIN='/usr/local/bin/shfmt'

# Run
main() (
    local arch work_dir version filename asset url checksum

    require_root
    if [[ "$(uname -s)" != 'Linux' ]]; then
        log_error 'Only Linux is supported'
        exit 1
    fi

    case "$(detect_architecture)" in
    x86_64) arch='amd64' ;;
    aarch64) arch='arm64' ;;
    *) exit 1 ;;
    esac

    require_cmd curl jq sha256sum install

    work_dir="$(mktemp -d)"
    trap 'rm -rf -- "${work_dir}"' EXIT

    log_info 'Resolving latest shfmt release...'
    curl -fsSL "${RELEASE_API}" -o "${work_dir}/release.json"
    version="$(jq -er '.tag_name | select(test("^v[0-9]+[.][0-9]+[.][0-9]+$"))' "${work_dir}/release.json")"
    filename="shfmt_${version}_linux_${arch}"
    asset="$(jq -er --arg name "${filename}" '
        .assets[] | select(.name == $name)
        | select((.digest // "") | test("^sha256:[0-9a-f]{64}$"))
        | [.browser_download_url, (.digest | ltrimstr("sha256:"))] | @tsv
    ' "${work_dir}/release.json")" || {
        log_error "Release asset or SHA-256 not found: ${filename}"
        exit 1
    }

    read -r url checksum <<<"${asset}"

    log_info "Downloading shfmt ${version} for Linux ${arch}..."
    curl -fsSL "${url}" -o "${work_dir}/${filename}"
    (cd "${work_dir}" && printf '%s  %s\n' "${checksum}" "${filename}" | sha256sum -c -)

    log_info "Installing shfmt to: ${SHFMT_BIN}..."
    install -D -o root -g root -m 755 "${work_dir}/${filename}" "${SHFMT_BIN}"
    version="$("${SHFMT_BIN}" --version)"
    log_success "shfmt installed: ${version}"
)

main "$@"
