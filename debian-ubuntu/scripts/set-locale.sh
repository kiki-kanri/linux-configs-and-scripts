#!/bin/bash

# Set locale and timezone to zh_TW.UTF-8 and Asia/Taipei

set -e
ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd "$ROOT_DIR"
. ./scripts/common.sh

# Set timezone and locale
sudo apt-get install locales tzdata
sudo ln -fs /usr/share/zoneinfo/Asia/Taipei /etc/localtime
sudo dpkg-reconfigure -f noninteractive tzdata
sudo locale-gen zh_TW.UTF-8
sudo update-locale LANG=zh_TW.UTF-8
sudo update-locale LANGUAGE=zh_TW.UTF-8
sudo update-locale LC_ALL=zh_TW.UTF-8
