#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${SCRIPTS_DIR}"

[[ " $@ " =~ ' -p ' ]] && docker compose pull

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

COMPOSE_BAKE=true docker compose build
docker compose up -d --remove-orphans
