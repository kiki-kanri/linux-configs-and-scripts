#!/bin/bash

ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd "$ROOT_DIR"
. ./scripts/common.sh

sudo cp -fp ./etc/systemd/system/setup-thp.service /etc/systemd/system/ &&
    sudo systemctl daemon-reload &&
    sudo systemctl enable setup-thp.service &&
    sudo systemctl start setup-thp.service
