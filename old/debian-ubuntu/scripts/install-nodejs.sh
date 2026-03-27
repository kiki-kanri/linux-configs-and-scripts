#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd -- "${SCRIPTS_DIR}/../" &>/dev/null && pwd)"
cd "${BASE_DIR}"

. ./scripts/common.sh

sudo apt-get update
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get update
sudo apt-get install -y nodejs
./etc/cron.daily/upgrade-npm-packages
