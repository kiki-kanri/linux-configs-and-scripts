#!/usr/bin/env bash

# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Constants/Variables
readonly AUTHORIZED_KEYS_FILE='/root/.ssh/authorized_keys'

# Functions

# Deployed with the stack and run on its host, so the shared log library is not available.
log_info() {
    printf '[INFO] %s\n' "$*"
}

log_success() {
    printf '[ OK ] %s\n' "$*"
}

log_warn() {
    printf '[WARN] %s\n' "$*" >&2
}

log_error() {
    printf '[ERROR] %s\n' "$*" >&2
}

# Run
main() {
    local key_blob
    local key_comment
    local key_type
    local options
    local public_key
    local rrsync_path
    local source_address

    # Root is used because rest-server writes the repositories as 0600 root files, which a separate account could
    # not read without changing how rest-server and add-user.sh create them.
    if ! rrsync_path="$(command -v rrsync)"; then
        log_error 'rrsync not found; install rsync'
        exit 1
    fi

    if [[ "$(sshd -T 2>/dev/null | awk '$1 == "permitrootlogin" { print $2 }')" == 'no' ]]; then
        log_warn 'sshd has PermitRootLogin no; set it to prohibit-password or forced-commands-only for this key to work'
    fi

    read -r -p 'Replica public key (one line, e.g. ssh-ed25519 AAAA... comment): ' public_key
    read -r key_type key_blob key_comment <<<"${public_key}"
    if [[ ! "${key_type}" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)|sk-[a-z0-9@.-]+)$ || -z "${key_blob}" ]]; then
        log_error 'Invalid public key'
        exit 1
    fi

    # Matched by the key itself, so re-running with the same key does not add a second entry.
    if [[ -f "${AUTHORIZED_KEYS_FILE}" ]] && grep -qF -- " ${key_blob}" "${AUTHORIZED_KEYS_FILE}"; then
        log_info "Key is already authorized: ${AUTHORIZED_KEYS_FILE}"
        exit 0
    fi

    read -r -p 'Restrict to the replica source IP or CIDR (empty for any): ' source_address

    # Read-only rsync of this stack only; restrict also turns off shells, PTYs and every kind of forwarding.
    options="command=\"${rrsync_path} -ro ${SCRIPT_DIR}\",restrict"
    if [[ -n "${source_address}" ]]; then
        options="from=\"${source_address}\",${options}"
    fi

    install -d -m 700 -- "$(dirname -- "${AUTHORIZED_KEYS_FILE}")"
    (
        umask 077
        {
            # sed adds the final newline the existing file may lack, so the new entry starts on its own line.
            if [[ -f "${AUTHORIZED_KEYS_FILE}" ]]; then
                # shellcheck disable=SC1003 # sed's append command, not an escaped quote.
                sed -e '$a\' -- "${AUTHORIZED_KEYS_FILE}"
            fi

            printf '%s %s %s %s\n' "${options}" "${key_type}" "${key_blob}" "${key_comment:-rest-server-replica}"
        } >"${AUTHORIZED_KEYS_FILE}.new"
    )

    mv -fT -- "${AUTHORIZED_KEYS_FILE}.new" "${AUTHORIZED_KEYS_FILE}"
    log_success "Authorized the replica key for read-only rsync of ${SCRIPT_DIR}"
    log_info 'Pull from the replica with paths relative to the stack, e.g. root@<this host>:data/'
}

main "$@"
