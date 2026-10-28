#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly INSTALL_URL='https://get.docker.com'

# Run
main() (
    local force=false
    local work_dir docker_version compose_version
    local ID VERSION_ID PRETTY_NAME

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

    require_cmd curl sh systemctl
    if command_exists docker && [[ "${force}" == false ]]; then
        docker_version="$(docker --version)"
        log_info "Docker is already installed: ${docker_version}; use -f to run the installer again"
    else
        work_dir="$(mktemp -d)"
        trap 'rm -rf -- "${work_dir}"' EXIT

        log_info 'Downloading Docker official installer...'
        curl -fsSL "${INSTALL_URL}" -o "${work_dir}/get-docker.sh"

        log_info 'Running Docker official installer...'
        sh "${work_dir}/get-docker.sh"
    fi

    log_info 'Enabling and starting Docker service...'
    systemctl enable --now docker

    docker_version="$(docker --version)"
    compose_version="$(docker compose version)"
    log_info "Docker version: ${docker_version}"
    log_info "Compose version: ${compose_version}"
    log_success 'Docker setup complete'
)

main "$@"
