#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd -- "${SCRIPTS_DIR}/../" &>/dev/null && pwd)"
cd "${BASE_DIR}"

. ./scripts/common.sh

# Install and setup ufw-docekr (https://github.com/chaifeng/ufw-docker#ufw-docker-%E5%B7%A5%E5%85%B7)

sudo wget -O /usr/local/bin/ufw-docker https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker
sudo chmod +x /usr/local/bin/ufw-docker
sudo ufw-docker install
sudo systemctl restart ufw
sudo ufw reload
