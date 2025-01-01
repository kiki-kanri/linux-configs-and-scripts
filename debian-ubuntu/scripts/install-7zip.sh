#!/bin/bash

set -e
ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd "$ROOT_DIR"
. ./scripts/common.sh

sudo mkdir -p /opt/7zip
cd /opt/7zip
sudo wget https://www.7-zip.org/a/7z2409-linux-x64.tar.xz
sudo tar -xvf 7z2409-linux-x64.tar.xz
sudo rm 7z2409-linux-x64.tar.xz
sudo ln -s /opt/7zip/7zz /usr/local/bin/7zz
sudo ln -s /opt/7zip/7zzs /usr/local/bin/7zzs
