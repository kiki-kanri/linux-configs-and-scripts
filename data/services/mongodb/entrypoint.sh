#!/bin/bash

cd "$(dirname "$(readlink -f "$0")")"
LD_PRELOAD=./libforce_enable_thp.so python3 /usr/local/bin/docker-entrypoint.py \
    --replSet rs0 &

if [ $(hostname) = "mongodb-main-data-1" ]; then
    until mongosh --eval 'print(\"Waiting for MongoDB connection...\")' --quiet; do
        sleep 1
    done

    echo 'Initializing replica set...'
    mongosh --eval "
      try {
        rs.status();
      } catch (error) {
        rs.initiate({
          _id: 'rs0',
          members: [
            { _id: 0, host: '$MONGODB_MAIN_RS_HOST:$MONGODB_MAIN_DATA_1_EXPOSE_PORT' },
            { _id: 1, host: '$MONGODB_MAIN_RS_HOST:$MONGODB_MAIN_DATA_2_EXPOSE_PORT' },
            { _id: 2, host: '$MONGODB_MAIN_RS_HOST:$MONGODB_MAIN_DATA_3_EXPOSE_PORT' },
          ]
        });
      }
    " --port 27017

    echo 'Replica set initialized.'
fi

tail -f /dev/null
