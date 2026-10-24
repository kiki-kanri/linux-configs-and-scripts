#!/usr/bin/env bash
# Compiler and linker flags for build-nginx.sh.
# shellcheck disable=SC2034

# Constants/Variables
NGINX_CC_OPT=(
    -fdata-sections
    -ffunction-sections
    -flto=thin
    -fomit-frame-pointer
    -fPIC
    -fstack-clash-protection
    -fstack-protector-strong
    -I"${QUICTLS_DIR}/build/include"
    -I"${QUICTLS_DIR}/include"
    -march=native
    -O3
    -pthread
    -Werror=format-security
    -Wformat
)

NGINX_LD_OPT=(
    -flto=thin
    -fuse-ld=lld
    -L"${QUICTLS_DIR}/build"
    -ldl
    -lpthread
    "-Wl,--as-needed"
    "-Wl,--gc-sections"
    "-Wl,-E"
    "-Wl,-O2"
    "-Wl,-rpath,${QUICTLS_DIR}/build"
    "-Wl,-z,now"
    "-Wl,-z,relro"
)

QUICTLS_CFLAGS=(
    -fdata-sections
    -ffunction-sections
    -fomit-frame-pointer
    -fPIC
    -fstack-clash-protection
    -fstack-protector-strong
    -fstrict-aliasing
    -g
    -march=native
    -O3
    -pthread
)

QUICTLS_LDFLAGS=()

# Functions

# Only these optional flags may be dropped; other build errors must remain fatal.
filter_optional_compiler_flags() {
    local -n flags="$1"
    shift
    local flag
    local filtered=()

    # Do not mistake an unavailable or broken compiler for unsupported flags.
    "$@" -Werror -x c -c /dev/null -o /dev/null || return 1

    for flag in "${flags[@]}"; do
        case "${flag}" in
        -march=native | -fstack-clash-protection)
            if ! "$@" -Werror "${flag}" -x c -c /dev/null -o /dev/null 2>/dev/null; then
                log_warn "Removing unsupported ${flag} for $*"
                continue
            fi
            ;;
        esac
        filtered+=("${flag}")
    done

    flags=("${filtered[@]}")
}
