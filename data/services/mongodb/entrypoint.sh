#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
cd "${SCRIPT_DIR}"

echo "[startup] Container started at $(date)"
echo "[startup] Hostname: $(hostname)"

ensure_replica_set_initialized() {
    until mongosh --eval 'print("Waiting for MongoDB connection...")' --quiet; do
        sleep 1
    done

    echo '[init] Initializing replica set...'
    mongosh --eval "
        try {
            rs.status();
        } catch (error) {
            rs.initiate({
                _id: 'rs0',
                members: [
                    { _id: 0, host: '${MONGODB_MAIN_RS_HOST}:${MONGODB_MAIN_DATA_1_EXPOSE_PORT}' },
                    { _id: 1, host: '${MONGODB_MAIN_RS_HOST}:${MONGODB_MAIN_DATA_2_EXPOSE_PORT}' },
                    { _id: 2, host: '${MONGODB_MAIN_RS_HOST}:${MONGODB_MAIN_DATA_3_EXPOSE_PORT}' },
                ]
            });
        }
    "

    echo '[init] Replica set initialized'
}

handle_sigterm() {
    echo '[trap] SIGTERM caught, forwarding to mongod...'
    pkill -TERM mongod
    echo '[trap] Waiting for mongod to exit...'
    wait "${PY_PID}"
}

[ "$(hostname)" = 'mongodb-main-data-1' ] && ensure_replica_set_initialized &
LD_PRELOAD='./libforce_enable_thp.so' python3 /usr/local/bin/docker-entrypoint.py --replSet rs0 &
PY_PID="$!"
trap handle_sigterm SIGTERM SIGINT
wait "${PY_PID}"
