#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd -- "${SCRIPTS_DIR}/../" &>/dev/null && pwd)"
cd "${BASE_DIR}"

. ./scripts/common.sh

if [ ! "${os_type}" = 'ubuntu' ] || [ ! "${os_version_id}" = '24.04' ]; then
    echo 'This script is only for Ubuntu 24.04'
    exit 1
fi

CUDA_ENV_VARS='
# CUDA Environment Variables
export CUDA_HOME=/usr/local/cuda
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"
export PATH="/usr/local/cuda/bin:${PATH}"
'

wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i ./cuda-keyring_1.1-1_all.deb
sudo apt update
sudo apt install --no-install-recommends nvidia-headless-580 nvidia-utils-580
sudo apt install --no-install-recommends cuda-toolkit-12-9
sudo apt install --no-install-recommends cudnn
sudo bash -c "echo \"${CUDA_ENV_VARS}\" >> /etc/bash.bashrc"
sudo bash -c "echo \"${CUDA_ENV_VARS}\" >> /etc/profile"
sudo rm ./cuda-keyring_1.1-1_all.deb
