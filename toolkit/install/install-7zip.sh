#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly RELEASE_API='https://api.github.com/repos/ip7z/7zip/releases/latest'
readonly INSTALL_DIR='/opt/7zip'

# Run
main() (
    local arch work_dir version filename asset url checksum

    require_root
    if [[ "$(uname -s)" != 'Linux' ]]; then
        log_error 'Only Linux is supported'
        exit 1
    fi

    case "$(detect_architecture)" in
    x86_64) arch='x64' ;;
    aarch64) arch='arm64' ;;
    *) exit 1 ;;
    esac

    require_cmd curl jq sha256sum tar xz cp find chmod install ln

    work_dir="$(mktemp -d)"
    trap 'rm -rf -- "${work_dir}"' EXIT

    log_info 'Resolving latest 7-Zip release...'
    curl -fsSL "${RELEASE_API}" -o "${work_dir}/release.json"
    version="$(jq -er '.tag_name | select(test("^[0-9]+[.][0-9]+$"))' "${work_dir}/release.json")"
    filename="7z${version//./}-linux-${arch}.tar.xz"
    asset="$(jq -er --arg name "${filename}" '
        .assets[] | select(.name == $name)
        | select((.digest // "") | test("^sha256:[0-9a-f]{64}$"))
        | [.browser_download_url, (.digest | ltrimstr("sha256:"))] | @tsv
    ' "${work_dir}/release.json")" || {
        log_error "Release asset or SHA-256 not found: ${filename}"
        exit 1
    }

    read -r url checksum <<<"${asset}"

    log_info "Downloading 7-Zip ${version} for Linux ${arch}..."
    curl -fsSL "${url}" -o "${work_dir}/${filename}"
    (cd "${work_dir}" && printf '%s  %s\n' "${checksum}" "${filename}" | sha256sum -c -)

    install -d "${work_dir}/archive"
    tar -xf "${work_dir}/${filename}" -C "${work_dir}/archive" --no-same-owner
    if [[ ! -x "${work_dir}/archive/7zz" || ! -x "${work_dir}/archive/7zzs" ]]; then
        log_error 'Archive does not contain executable 7zz and 7zzs binaries'
        exit 1
    fi

    log_info "Installing 7-Zip to: ${INSTALL_DIR}..."
    rm -rf -- "${INSTALL_DIR}"
    install -d -m 755 "${INSTALL_DIR}" /usr/local/bin
    cp -R "${work_dir}/archive/." "${INSTALL_DIR}/"
    find "${INSTALL_DIR}" -type d -exec chmod 755 {} +
    find "${INSTALL_DIR}" -type f -exec chmod 644 {} +
    chmod 755 "${INSTALL_DIR}/7zz" "${INSTALL_DIR}/7zzs"
    ln -sfn "${INSTALL_DIR}/7zz" /usr/local/bin/7zz
    ln -sfn "${INSTALL_DIR}/7zzs" /usr/local/bin/7zzs

    log_success "7-Zip ${version} installed: /usr/local/bin/7zz and /usr/local/bin/7zzs"
)

main "$@"
