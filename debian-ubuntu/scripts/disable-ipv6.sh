#!/bin/bash

set -e

BASE_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../")"
cd "$BASE_DIR"

. ./scripts/common.sh

sudo cp -fp ./etc/sysctl.d/disable-ipv6.conf /etc/sysctl.d/
sudo sysctl --system
