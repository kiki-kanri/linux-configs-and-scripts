#!/bin/sh

set -e

KEYDB_MAIN_PASSWORD=$(cat /run/secrets/KEYDB_MAIN_PASSWORD)

if [ -n "$KEYDB_MAIN_PASSWORD" ]; then
    if [ "${#KEYDB_MAIN_PASSWORD}" -ge 96 ]; then
        exec keydb-server /etc/keydb/keydb.conf --requirepass "$KEYDB_MAIN_PASSWORD"
    else
        echo 'Error: "KEYDB_MAIN_PASSWORD" length must be at least 96 characters.' >&2
        exit 1
    fi
else
    exec keydb-server /etc/keydb/keydb.conf
fi
