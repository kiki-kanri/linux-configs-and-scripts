#!/bin/bash

set -euo pipefail

readonly KEYFILE_PATH='/data/configdb/keyfile'

if [ ! -s "${KEYFILE_PATH}" ]; then
    echo 'Warning: MongoDB keyfile does not exist; generating a persistent keyfile' >&2

    KEYFILE_TMP="$(mktemp "${KEYFILE_PATH}.XXXXXX")"
    trap 'rm -f "${KEYFILE_TMP}"' EXIT

    head -c 756 /dev/urandom | base64 | tr -d '\n' >"${KEYFILE_TMP}"
    chmod 400 "${KEYFILE_TMP}"
    mv "${KEYFILE_TMP}" "${KEYFILE_PATH}"

    trap - EXIT
fi

chmod 400 "${KEYFILE_PATH}"

exec /usr/local/bin/docker-entrypoint "$@"
