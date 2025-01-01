#!/bin/bash

set -e
ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd "$ROOT_DIR"
. ./scripts/common.sh

sudo cp -f ./etc/update-motd.d/9999-cat /etc/update-motd.d/
sudo chmod 700 /etc/update-motd.d/9999-cat
