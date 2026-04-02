#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# os.sh — OS and version detection for linux-configs-and-scripts
#
# Provides:
#   detect_os()          — returns: debian-<version> | ubuntu-<version>
#   detect_os_codename() — returns: bookworm | jammy | noble | ...
#   is_debian()
#   is_ubuntu()
#   os_version()         — returns just the version number (e.g. 12, 22.04, 24.04)

_detect_os_cached() {
    # Parse /etc/os-release once per shell session.
    # Returns: "id version codename" (space-separated, e.g. "debian 12 bookworm")
    if [[ -z "${_OS_INFO:-}" ]]; then
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            case "${ID}" in
            debian | ubuntu)
                _OS_INFO="${ID} ${VERSION_ID} ${VERSION_CODENAME:-unknown}"
                ;;
            *)
                echo "unsupported" >&2
                return 1
                ;;
            esac
        else
            echo "unsupported" >&2
            return 1
        fi
    fi
    printf '%s\n' "${_OS_INFO}"
}

detect_os() {
    local info id version
    info="$(_detect_os_cached)" || return 1
    set -- ${info}
    id="$1"
    version="$2"
    printf '%s-%s\n' "${id}" "${version}"
}

detect_os_codename() {
    local info
    info="$(_detect_os_cached)" || return 1
    set -- ${info}
    printf '%s\n' "$3"
}

os_version() {
    local info
    info="$(_detect_os_cached)" || return 1
    set -- ${info}
    printf '%s\n' "$2"
}

# Convenience predicates
is_debian() {
    local info
    info="$(_detect_os_cached)" || return 1
    [[ "${info%% *}" == "debian" ]]
}

is_ubuntu() {
    local info
    info="$(_detect_os_cached)" || return 1
    [[ "${info%% *}" == "ubuntu" ]]
}
