#!/bin/bash

set -e

BASE_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../")"
cd "$BASE_DIR"

. ./scripts/common.sh

sudo apt-get update
sudo apt-get install -y \
    acl \
    colormake \
    cron \
    curl \
    g++ \
    gcc \
    htop \
    iftop \
    iotop \
    iputils-ping \
    lsof \
    nmap \
    net-tools \
    perl \
    screen \
    tar \
    tmux \
    unzip \
    vim \
    wget

sudo apt-get autoremove -y --purge
sudo apt-get autoclean
