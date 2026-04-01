#!/bin/bash

set -euo pipefail

log_green() {
    echo -e "\033[32m$*\033[0m"
}

log_red() {
    echo -e "\033[31m$*\033[0m"
}

rsync_dir() {
    old_mode="$(stat -c '%a' "${1}")"
    rsync -av --progress "./files${1}" "${1}"
    chmod "${old_mode}" "${1}"
}
