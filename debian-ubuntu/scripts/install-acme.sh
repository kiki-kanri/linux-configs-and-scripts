#!/bin/bash

read -p '請輸入email: ' EMAIL

apt-get update &&
    apt-get install -y cron &&
    cd /tmp &&
    git clone https://github.com/acmesh-official/acme.sh.git &&
    cd ./acme.sh &&
    ./acme.sh --install -m $EMAIL &&
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade &&
    cd /tmp &&
    rm -rf ./acme.sh
