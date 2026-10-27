#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly BASE_PACKAGES_FILE="${REPO_ROOT}/toolkit/conf/packages/base.txt"

# Run
main() (
    local initial_setup=false
    local ID VERSION_ID PRETTY_NAME
    local -a base_packages release_packages

    while (($# > 0)); do
        case "$1" in
        --initial-setup) initial_setup=true ;;
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
    debian:13)
        # Debian 13 replaced dnsutils and removed software-properties-common.
        release_packages=(bind9-dnsutils)
        ;;
    debian:12 | ubuntu:24.04 | ubuntu:26.04)
        release_packages=(dnsutils software-properties-common)
        ;;
    *)
        log_error "Unsupported operating system release: ${PRETTY_NAME}"
        exit 1
        ;;
    esac

    mapfile -t base_packages <"${BASE_PACKAGES_FILE}"
    base_packages+=("${release_packages[@]}")

    log_info 'Updating package index...'
    apt-get update

    if "${initial_setup}"; then
        log_info 'Upgrading installed packages...'
        apt-get upgrade -y
    fi

    log_info 'Installing base packages...'
    apt-get install -y --no-install-recommends "${base_packages[@]}"

    if "${initial_setup}"; then
        log_info 'Removing open-vm-tools and unused dependencies...'
        apt-get remove -y --auto-remove --purge open-vm-tools
    fi

    log_success 'Base packages installed'
)

main "$@"
