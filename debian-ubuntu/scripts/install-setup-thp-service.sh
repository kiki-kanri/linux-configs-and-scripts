#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd -- "${SCRIPTS_DIR}/../" &>/dev/null && pwd)"
cd "${BASE_DIR}"

. ./scripts/common.sh

sudo cp -fp ./etc/systemd/system/setup-thp.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable setup-thp.service
sudo systemctl start setup-thp.service
