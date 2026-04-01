#!/bin/bash

set -euo pipefail

rsync_dir() {
    old_mode="$(stat -c '%a' "${1}")"
    rsync -av --progress "./files${1}" "${1}"
    chmod "${old_mode}" "${1}"
}
