#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC2034,SC1091

if [[ -n "${SCRIPT_LIBS_COMMON_LOADED:-}" ]]; then
    return 0
fi

SCRIPT_LIBS_COMMON_LOADED=1

LIBS_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P -- "${LIBS_DIR}/../.." && pwd)"

# Support both the source layout (<repo>/libs/public) and the copy target
# (<repo>/scripts/libs/public).
if [[ "$(basename -- "${REPO_ROOT}")" == 'scripts' && ! -e "${REPO_ROOT}/.git" ]]; then
    REPO_ROOT="$(cd -P -- "${REPO_ROOT}/.." && pwd)"
fi

: "${SCRIPT_NAME:=$(basename -- "${BASH_SOURCE[1]:-$0}" .sh)}"
: "${SCRIPT_DIR:=$(cd -P -- "$(dirname -- "${BASH_SOURCE[1]:-$0}")" && pwd)}"

source "${LIBS_DIR}/log.sh"
source "${LIBS_DIR}/command.sh"
source "${LIBS_DIR}/file.sh"
source "${LIBS_DIR}/path.sh"
source "${LIBS_DIR}/platform.sh"
source "${LIBS_DIR}/prompt.sh"
source "${LIBS_DIR}/rust.sh"
