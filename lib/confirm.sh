#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# confirm.sh — Interactive yes/no confirmation prompt
#
# Usage:
#   confirm "Continue?"                    # defaults to "no"
#   confirm "Continue?" --default=yes     # defaults to "yes"
#   confirm "Continue?" --force           # skip prompt, return 0 (for unattended scripts)

confirm() {
    local prompt="$1"
    local default=""
    local force=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --default=yes | -y) default="yes" ;;
        --default=no | -n) default="no" ;;
        --force | -f) force=true ;;
        esac
        shift
    done

    if "${force}"; then
        return 0
    fi

    local answer
    local options="[y/N]"
    [[ "${default}" == "yes" ]] && options="[Y/n]"

    while true; do
        printf '%s %s: ' "${prompt}" "${options}" >&2
        read -r answer </dev/tty 2>/dev/null || {
            # Fallback if tty unavailable (non-interactive)
            answer=""
        }

        # Empty input -> use default
        if [[ -z "${answer}" ]]; then
            answer="${default}"
        fi

        case "${answer}" in
        y | Y | yes | Yes | YES)
            return 0
            ;;
        n | N | no | No | NO)
            return 1
            ;;
        *)
            echo "Please answer y or n." >&2
            ;;
        esac
    done
}
