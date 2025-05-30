#!/bin/bash

set -e

BASE_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../")"
cd "${BASE_DIR}"

. ./scripts/common.sh

sudo apt-get update
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get update
sudo apt-get install -y nodejs
./etc/cron.daily/upgrade-npm-packages
