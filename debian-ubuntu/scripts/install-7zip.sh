#!/bin/bash

set -e

BASE_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../")"
cd "${BASE_DIR}"

. ./scripts/common.sh

sudo rm -rf /opt/7zip
sudo mkdir -p /opt/7zip
cd /opt/7zip
sudo wget https://www.7-zip.org/a/7z2500-linux-x64.tar.xz
sudo tar -xvf 7z2500-linux-x64.tar.xz
sudo rm 7z2500-linux-x64.tar.xz
sudo rm -rf /usr/local/bin/7zz /usr/local/bin/7zzs
sudo ln -s /opt/7zip/7zz /usr/local/bin/7zz
sudo ln -s /opt/7zip/7zzs /usr/local/bin/7zzs
