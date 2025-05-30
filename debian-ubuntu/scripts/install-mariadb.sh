#!/bin/bash

set -e

BASE_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../")"
cd "${BASE_DIR}"

. ./scripts/common.sh

cd /tmp/
sudo curl -LsS -O https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
sudo bash mariadb_repo_setup --mariadb-server-version=11.7.2
sudo rm -rf /etc/apt/sources.list.d/mariadb.list.*
sudo apt-get install mariadb-server
sudo systemctl enable mariadb
sudo systemctl start mariadb
sudo rm mariadb_repo_setup
