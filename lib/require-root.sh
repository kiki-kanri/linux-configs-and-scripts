#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# require-root.sh — Check that the script is running as root

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        echo "ERROR: This script must be run as root." >&2
        echo "Hint: try 'sudo ${0}'" >&2
        exit 1
    fi
}
