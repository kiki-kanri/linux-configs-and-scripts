#!/usr/bin/env bash

# shellcheck shell=bash

if [[ -n "${SCRIPT_LIBS_PLATFORM_LOADED:-}" ]]; then
    return 0
fi

SCRIPT_LIBS_PLATFORM_LOADED=1

host_os() {
    case "$(uname -s)" in
    Linux) printf 'linux\n' ;;
    Darwin) printf 'macos\n' ;;
    MINGW* | MSYS* | CYGWIN*) printf 'windows\n' ;;
    *) printf 'unknown\n' ;;
    esac
}

host_arch() {
    case "$(uname -m)" in
    x86_64 | amd64) printf 'x86_64\n' ;;
    arm64 | aarch64) printf 'aarch64\n' ;;
    armv7l | armv7*) printf 'armv7\n' ;;
    *) uname -m ;;
    esac
}

detect_architecture() {
    case "$(host_arch)" in
    x86_64) printf 'x86_64\n' ;;
    aarch64) printf 'aarch64\n' ;;
    *)
        log_error "Unsupported architecture: $(uname -m)"
        return 1
        ;;
    esac
}
