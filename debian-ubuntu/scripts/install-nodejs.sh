#!/bin/bash

ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd "$ROOT_DIR"
. ./scripts/common.sh

sudo apt-get update &&
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - &&
    sudo apt-get update &&
    sudo apt-get install -y nodejs &&
    sudo npm upgrade -g &&
    sudo corepack disable pnpm &&
    sudo npm i npm@latest pnpm@latest -g
