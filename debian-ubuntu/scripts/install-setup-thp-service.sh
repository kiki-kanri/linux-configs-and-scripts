#!/bin/bash

set -e

BASE_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../")"
cd "${BASE_DIR}"

. ./scripts/common.sh

sudo cp -fp ./etc/systemd/system/setup-thp.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable setup-thp.service
sudo systemctl start setup-thp.service
