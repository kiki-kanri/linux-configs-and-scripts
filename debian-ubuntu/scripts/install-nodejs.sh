#!/bin/bash

set -e

ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd "$ROOT_DIR"
. ./scripts/common.sh

sudo apt-get update
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get update
sudo apt-get install -y nodejs
../etc/cron.daily/upgrade-npm-packages
