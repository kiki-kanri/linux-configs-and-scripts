#!/bin/bash

# Functions
install_file() {
    local mode="${1}"
    local src="${2}"
    local user="${3:-root}"
    local group="${4:-$user}"

    local src_path="${BASE_DIR}/${src}"
    local dest="/${src}"

    echo "Installing ${src_path} -> ${dest} (mode=${mode}, owner=${user}:${group})"
    if [[ ! -f "${src_path}" ]]; then
        log_red "Source file not found: ${src_path}"
        return 1
    fi

    sudo install -o "${user}" -g "${group}" -Dm"${mode}" "${src_path}" "${dest}"
}

log_green() {
    echo -e "\033[32m$*\033[0m"
}

log_red() {
    echo -e "\033[31m$*\033[0m"
}

# Run
cd /tmp
apt-get update
apt-get install -y git
rm -rf ./linux-configs-and-scripts/
git clone https://github.com/kiki-kanri/linux-configs-and-scripts
cd ./linux-configs-and-scripts/ubuntu/24.04/

log_green 'Installing base packages...'
apt-get install -y bash-completion bsdmainutils htop locales lsd lsof vim ufw

log_green 'Installing files...'
