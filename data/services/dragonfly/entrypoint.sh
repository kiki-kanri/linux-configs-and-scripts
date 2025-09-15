#!/bin/bash

set -euo pipefail

DRAGONFLY_MAIN_PASSWORD="$(cat /run/secrets/DRAGONFLY_MAIN_PASSWORD)"

if [ -n "${DRAGONFLY_MAIN_PASSWORD}" ]; then
    if [ "${#DRAGONFLY_MAIN_PASSWORD}" -ge 96 ]; then
        exec dragonfly --logtostderr --requirepass "${DRAGONFLY_MAIN_PASSWORD}"
    else
        echo 'Error: "DRAGONFLY_MAIN_PASSWORD" length must be at least 96 characters' >&2
        exit 1
    fi
else
    exec dragonfly --logtostderr
fi
