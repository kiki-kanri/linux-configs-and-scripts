#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd -- "${SCRIPTS_DIR}/../" &>/dev/null && pwd)"
cd "${BASE_DIR}"

. ./scripts/common.sh

sudo cp -fp ./etc/sysctl.d/disable-ipv6.conf /etc/sysctl.d/
sudo sysctl --system
