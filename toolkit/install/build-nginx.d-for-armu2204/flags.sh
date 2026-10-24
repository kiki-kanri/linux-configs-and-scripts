#!/usr/bin/env bash
# Compiler and linker flags for build-nginx.sh.
# shellcheck disable=SC2034

NGINX_CC_OPT=(
    -fdata-sections
    -ffunction-sections
    -flto=thin
    -fomit-frame-pointer
    -fPIC
    -fstack-protector-strong
    -mcpu=native
    -O3
    -pthread
    -Werror=format-security
    -Wformat
)

NGINX_LD_OPT=(
    -flto=thin
    -fuse-ld=lld
    -ldl
    -lpthread
    "-Wl,--as-needed"
    "-Wl,--gc-sections"
    "-Wl,-E"
    "-Wl,-O2"
    "-Wl,-z,now"
    "-Wl,-z,relro"
)
