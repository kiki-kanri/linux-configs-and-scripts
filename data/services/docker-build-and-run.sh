#!/bin/bash

set -e
cd "$(dirname "$(readlink -f "$0")")"

if [[ "$*" == *'-p'* ]]; then
    docker compose pull
fi

gcc \
    -fPIC \
    -fstack-protector-strong \
    -march=native \
    -O3 \
    -shared \
    -Werror=format-security \
    -Wformat \
    -o ./mongodb/libforce_enable_thp.so \
    ./mongodb/force_enable_thp.c \
    -ldl \
    -Wl,--as-needed \
    -Wl,-O2 \
    -Wl,-z,now \
    -Wl,-z,relro

docker compose build
docker compose up -d --remove-orphans
