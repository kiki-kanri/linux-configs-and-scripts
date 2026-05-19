#!/usr/bin/env bash
# Compiler and linker flags for build-nginx.sh.
# shellcheck disable=SC2034

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
