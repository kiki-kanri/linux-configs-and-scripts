#!/bin/bash

set -e

BASE_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../")"
cd "${BASE_DIR}"

. ./scripts/common.sh

sudo apt-get update

if [ "${os_type}" = 'debian' ]; then
    for package in docker.io docker-doc docker-compose podman-docker containerd runc; do
        sudo apt-get remove -y --auto-remove --purge "${package}";
    done
elif [ "${os_type}" = 'ubuntu' ]; then
    for package in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        sudo apt-get remove -y --auto-remove --purge "${package}";
    done
fi

sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL "https://download.docker.com/linux/${os_type}/gpg" -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] "https://download.docker.com/linux/${os_type}" \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update
sudo apt-get install \
    containerd.io \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    docker-buildx-plugin

sudo systemctl enable docker
sudo systemctl start docker
