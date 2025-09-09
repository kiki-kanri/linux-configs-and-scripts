#!/bin/bash

set -euo pipefail

read -p '請輸入email: ' EMAIL

apt-get update
apt-get install -y cron

cd /tmp
git clone https://github.com/acmesh-official/acme.sh.git
cd ./acme.sh
./acme.sh --install -m "${EMAIL}"
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --upgrade --auto-upgrade
cd /tmp
rm -rf ./acme.sh
