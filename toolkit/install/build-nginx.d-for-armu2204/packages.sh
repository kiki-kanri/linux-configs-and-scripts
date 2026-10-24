#!/usr/bin/env bash
# Package groups for build-nginx.sh.
# shellcheck disable=SC2034

BUILD_PACKAGES=(
    clang
    libbrotli-dev
    libgeoip-dev
    libmaxminddb-dev
    libpcre2-dev
    libssl-dev
    libzstd-dev
    lld
    llvm
    zlib1g-dev
)

BUILD_TOOLS=(
    binutils
    g++
    gcc
    git
    make
    pkg-config
    rsync
    tar
    wget
)

RUNTIME_PACKAGES=(
    geoip-bin
    geoip-database
    libbrotli1
    libgeoip1
    libmaxminddb0
    libpcre2-8-0
    libssl3
    libzstd1
    zlib1g
)
