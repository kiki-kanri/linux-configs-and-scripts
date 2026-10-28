#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly NODE_VERSION='26.x'
readonly NODESOURCE_SETUP_URL="https://deb.nodesource.com/setup_${NODE_VERSION}"

# Run
main() (
    local force=false
    local work_dir arch node_version npm_version
    local ID VERSION_ID PRETTY_NAME
    local -a install_args=(-y)

    while (($# > 0)); do
        case "$1" in
        -f) force=true ;;
        *)
            log_error "Unknown argument: $1"
            exit 2
            ;;
        esac
        shift
    done

    require_root
    source /etc/os-release
    case "${ID}:${VERSION_ID}" in
    debian:12 | debian:13 | ubuntu:24.04 | ubuntu:26.04) ;;
    *)
        log_error "Unsupported operating system release: ${PRETTY_NAME}"
        exit 1
        ;;
    esac

    arch="$(dpkg --print-architecture)"
    case "${arch}" in
    amd64 | arm64) ;;
    *)
        log_error "Unsupported architecture: ${arch}"
        exit 1
        ;;
    esac

    require_cmd apt-get bash curl
    if command_exists node && [[ "${force}" == false ]]; then
        node_version="$(node --version)"
        log_info "Node.js is already installed: ${node_version}; use -f to reinstall ${NODE_VERSION}"
    else
        work_dir="$(mktemp -d)"
        trap 'rm -rf -- "${work_dir}"' EXIT

        log_info "Setting up NodeSource repository for Node.js ${NODE_VERSION}..."
        curl -fsSL "${NODESOURCE_SETUP_URL}" -o "${work_dir}/nodesource-setup.sh"
        bash "${work_dir}/nodesource-setup.sh"

        log_info 'Installing Node.js...'
        apt-get update
        if "${force}"; then
            install_args+=(--reinstall)
        fi

        apt-get install "${install_args[@]}" nodejs
    fi

    log_info 'Updating npm...'
    npm install -g npm@latest

    node_version="$(node --version)"
    npm_version="$(npm --version)"
    log_success "Node.js setup complete: Node.js ${node_version}; npm ${npm_version}"
)

main "$@"
