#!/bin/bash

set -e

BASE_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../")"
cd "${BASE_DIR}"

. ./scripts/common.sh

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates lsb-release software-properties-common
sudo add-apt-repository ppa:ondrej/php
sudo apt-get install php8.4 php8.4-{bcmath,bz2,cli,common,curl,fpm,gd,gmp,http,imagick,imap,mbstring,mongodb,mysql,pcov,pq,raphf,readline,redis,swoole,xml,yaml,zip,zstd}
sudo systemctl enable php8.4-fpm
sudo systemctl start php8.4-fpm
