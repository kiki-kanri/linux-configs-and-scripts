#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC2034

# Package groups for build-nginx.sh.

# Constants/Variables
readonly -a BUILD_PACKAGES=(
    clang
    cmake
    libgeoip-dev
    libmaxminddb-dev
    libpcre2-dev
    libzstd-dev
    lld
    llvm
    ninja-build
    zlib1g-dev
)

readonly -a BUILD_TOOLS=(
    binutils
    g++
    gcc
    git
    gpg
    gpgv
    make
    pkg-config
    rsync
    tar
    wget
)

readonly -a RUNTIME_PACKAGES=(
    geoip-bin
    geoip-database
    libgeoip1
    libmaxminddb0
    libpcre2-8-0
    libzstd1
    zlib1g
)
