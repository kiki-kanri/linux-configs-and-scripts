#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# lib.sh — Ubuntu bootstrap helper library (sourced by setup.sh)

set -euo pipefail

rsync_dir() {
    old_mode="$(stat -c '%a' "${1}")"
    rsync -av "./files${1}" "${1}"
    chmod "${old_mode}" "${1}"
}
