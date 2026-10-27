#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

# Constants/Variables
readonly REPO_URL='https://github.com/kiki-kanri/linux-configs-and-scripts'
# shellcheck disable=SC2034 # Consumed by the shared logging library after cloning.
readonly SCRIPT_NAME='setup-ubuntu'

# Run
main() (
    local work_dir commit
    local ID VERSION_ID PRETTY_NAME

    # This curl | bash entry point has no repository libraries until the clone exists.
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        printf '[setup-ubuntu] ERROR: This script must be run as root\n' >&2
        exit 1
    fi

    source /etc/os-release
    case "${ID}:${VERSION_ID}" in
    ubuntu:24.04 | ubuntu:26.04) ;;
    *)
        printf '[setup-ubuntu] ERROR: Unsupported release: %s\n' "${PRETTY_NAME}" >&2
        exit 1
        ;;
    esac

    printf '[setup-ubuntu] INFO: Installing bootstrap dependencies...\n'
    apt-get update
    apt-get install -y ca-certificates curl git iproute2

    work_dir="$(mktemp -d /tmp/linux-configs-and-scripts.XXXXXX)"
    trap 'rm -rf -- "${work_dir}"' EXIT

    printf '[setup-ubuntu] INFO: Cloning linux-configs-and-scripts...\n'
    git clone "${REPO_URL}" "${work_dir}"
    commit="$(git -C "${work_dir}" rev-parse HEAD)"
    printf '[setup-ubuntu] INFO: Using repository commit: %s\n' "${commit}"

    SCRIPT_DIR="${work_dir}/bootstrap/ubuntu/setup"
    readonly SCRIPT_DIR
    source "${SCRIPT_DIR}/../../../libs/common.sh"
    source "${SCRIPT_DIR}/workflow.sh"

    "${REPO_ROOT}/modify-files-permissions.sh"
    setup_ubuntu
)

main "$@"
