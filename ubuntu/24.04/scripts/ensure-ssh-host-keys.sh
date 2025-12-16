#!/bin/bash

[ ! -f /etc/ssh/ssh_host_rsa_key ] && ssh-keygen -N '' -t rsa -f /etc/ssh/ssh_host_rsa_key
[ ! -f /etc/ssh/ssh_host_ecdsa_key ] && ssh-keygen -N '' -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key
[ ! -f /etc/ssh/ssh_host_ed25519_key ] && ssh-keygen -N '' -t ed25519 -f /etc/ssh/ssh_host_ed25519_key
chmod 600 /etc/ssh/ssh_host_*
chown root:root /etc/ssh/ssh_host_*

max_retry=20
retry=0
until systemctl restart ssh; do
    retry=$((retry + 1))
    if [ "$retry" -ge "$max_retry" ]; then
        echo "ssh restart failed after ${max_retry} attempts" >&2
        exit 1
    fi

    sleep 3
done
