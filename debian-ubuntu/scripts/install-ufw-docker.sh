#!/bin/bash

# Install and setup ufw-docekr (https://github.com/chaifeng/ufw-docker#ufw-docker-%E5%B7%A5%E5%85%B7)

ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd "$ROOT_DIR"
. ./scripts/common.sh

sudo wget -O /usr/local/bin/ufw-docker https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker &&
    sudo chmod +x /usr/local/bin/ufw-docker &&
    sudo ufw-docker install &&
    sudo systemctl restart ufw &&
    sudo ufw reload
