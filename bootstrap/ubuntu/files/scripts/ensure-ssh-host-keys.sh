#!/usr/bin/env bash
# Ensure SSH host keys exist, then restart SSH with retry.

set -euo pipefail

MAX_RETRY=20
RETRY_DELAY=3

create_host_key_if_missing() {
    local type="$1"
    local path="$2"

    [[ -f "${path}" ]] && return 0
    ssh-keygen -q -N '' -t "${type}" -f "${path}"
}

restart_ssh_with_retry() {
    local retry=0

    until systemctl restart ssh; do
        retry=$((retry + 1))
        if ((retry >= MAX_RETRY)); then
            printf 'ssh restart failed after %s attempts\n' "${MAX_RETRY}" >&2
            exit 1
        fi

        sleep "${RETRY_DELAY}"
    done
}

create_host_key_if_missing rsa /etc/ssh/ssh_host_rsa_key
create_host_key_if_missing ecdsa /etc/ssh/ssh_host_ecdsa_key
create_host_key_if_missing ed25519 /etc/ssh/ssh_host_ed25519_key
chmod 600 /etc/ssh/ssh_host_*
chown root:root /etc/ssh/ssh_host_*
restart_ssh_with_retry
