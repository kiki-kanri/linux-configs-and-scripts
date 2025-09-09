#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd -- "${SCRIPTS_DIR}/../" &>/dev/null && pwd)"
cd "${BASE_DIR}"

. ./scripts/common.sh

# Constants
FILE_NAME="7z2501-linux-x64.tar.xz"

# Run
sudo rm -rf /opt/7zip
sudo mkdir -p /opt/7zip
cd /opt/7zip
sudo wget "https://www.7-zip.org/a/${FILE_NAME}"
sudo tar -xvf "${FILE_NAME}"
sudo rm "${FILE_NAME}"
sudo rm -rf /usr/local/bin/7zz /usr/local/bin/7zzs
sudo ln -s /opt/7zip/7zz /usr/local/bin/7zz
sudo ln -s /opt/7zip/7zzs /usr/local/bin/7zzs
