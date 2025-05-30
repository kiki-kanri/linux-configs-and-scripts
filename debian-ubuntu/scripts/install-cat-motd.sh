#!/bin/bash

set -e

BASE_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../")"
cd "${BASE_DIR}"

. ./scripts/common.sh

sudo cp -f ./etc/update-motd.d/9999-cat /etc/update-motd.d/
sudo chmod 700 /etc/update-motd.d/9999-cat
