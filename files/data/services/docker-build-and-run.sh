#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

find ./stacks -type d -name opt -exec chmod 755 {} +
find ./stacks -type f -path '*/opt/*.sh' -exec chmod 755 {} +

for arg in "$@"; do
    if [[ "${arg}" == '-p' ]]; then
        docker compose pull
        break
    fi
done

docker compose up -d --remove-orphans
