#!/bin/bash

set -e

BASE_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../")"
cd "$BASE_DIR"

. ./scripts/common.sh

cd /etc/update-motd.d
sudo chmod -x 10-help-text 50-landscape-sysinfo 50-motd-news 90-updates-available
