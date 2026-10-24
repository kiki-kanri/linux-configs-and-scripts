#!/usr/bin/env bash

# shellcheck disable=SC2034

# Compiler and linker flags for build-nginx.sh.

# Constants/Variables
readonly -a BROTLI_CFLAGS=(
    -U_FORTIFY_SOURCE
    -D_FORTIFY_SOURCE=2
    -DNDEBUG
    -fdata-sections
    -ffunction-sections
    -fomit-frame-pointer
    -fPIC
    -fstack-clash-protection
    -fstack-protector-strong
    -fstrict-aliasing
    -march=native
    -O3
)

readonly -a NGINX_CFLAGS=(
    -U_FORTIFY_SOURCE
    -D_FORTIFY_SOURCE=2
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

readonly -a NGINX_LDFLAGS=(
    -flto=thin
    -fuse-ld=lld
    -L"${QUICTLS_DIR}/build"
    -ldl
    -lpthread
    '-Wl,--as-needed'
    '-Wl,--gc-sections'
    '-Wl,-E'
    '-Wl,-O2'
    "-Wl,-rpath,${QUICTLS_DIR}/build"
    '-Wl,-z,noexecstack'
    '-Wl,-z,now'
    '-Wl,-z,relro'
)

readonly -a QUICTLS_CFLAGS=(
    -U_FORTIFY_SOURCE
    -D_FORTIFY_SOURCE=2
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

readonly -a QUICTLS_LDFLAGS=(
    '-Wl,-z,noexecstack'
    '-Wl,-z,now'
    '-Wl,-z,relro'
)
