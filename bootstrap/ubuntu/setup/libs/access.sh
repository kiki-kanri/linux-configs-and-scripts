#!/usr/bin/env bash

# shellcheck shell=bash

# Functions
read_ssh_port() {
    local port

    while true; do
        printf 'Enter SSH port: ' >/dev/tty
        read -r port </dev/tty || return 1
        if [[ ! "${port}" =~ ^[0-9]+$ ]]; then
            log_error 'Invalid port; must be a number'
            continue
        fi

        if ((port < 1 || port > 65535)); then
            log_error 'Invalid port; must be 1-65535'
            continue
        fi

        printf '%s\n' "${port}"
        return 0
    done
}

configure_bootstrap_access() {
    local ssh_port="$1"

    log_info "Setting SSH port: ${ssh_port}..."
    sed -i "s/SSH_PORT/${ssh_port}/" /etc/ssh/sshd_config

    log_info 'Setting up UFW...'
    sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
    ufw allow "${ssh_port}"/tcp comment ssh
    log_success 'UFW rule added; enable it with: ufw enable'
}
