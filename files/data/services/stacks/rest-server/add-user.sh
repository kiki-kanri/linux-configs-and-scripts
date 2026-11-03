#!/usr/bin/env bash

# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Constants/Variables
readonly CONTAINER_NAME='rest-server'
readonly REPOSITORY_PASSWORDS_DIR="${SCRIPT_DIR}/repository-passwords"

# Functions

# Deployed with the stack and run on its host, so the shared log library is not available.
log_success() {
    printf '[ OK ] %s\n' "$*"
}

log_error() {
    printf '[ERROR] %s\n' "$*" >&2
}

# Leaves out whitespace, quotes, backslashes and shell metacharacters so the password survives TOML, htpasswd, restic's
# password file and copy-pasting. 48 characters stay under bcrypt's 72-byte limit.
generate_password() {
    head -c 4096 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9#%+,.:=@^_~-' | head -c 48
}

# Run
main() {
    local repository_password
    local rest_password
    local status=0
    local username

    read -r -p 'Username (the backup machine hostname): ' username

    # Used as the repository path under --private-repos, so keep it URL- and htpasswd-safe.
    if [[ ! "${username}" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
        log_error "Invalid username: ${username}; use lowercase letters, digits, '.', '_' or '-'"
        exit 1
    fi

    # create_user on an existing user silently resets the password that machine is using.
    docker exec "${CONTAINER_NAME}" grep -q -- "^${username}:" /auth/.htpasswd || status=$?
    case "${status}" in
    0)
        log_error "User already exists: ${username}"
        exit 1
        ;;
    1) ;;
    *)
        log_error "Failed to read /auth/.htpasswd in ${CONTAINER_NAME}"
        exit 1
        ;;
    esac

    # An existing file may already encrypt a repository left over from a deleted user.
    if [[ -e "${REPOSITORY_PASSWORDS_DIR}/${username}" ]]; then
        log_error "Repository password already exists: ${REPOSITORY_PASSWORDS_DIR}/${username}"
        exit 1
    fi

    repository_password="$(generate_password)"
    rest_password="$(generate_password)"

    # Saved before creating the user, so a machine can never back up to a repository this host cannot open.
    mkdir -p -- "${REPOSITORY_PASSWORDS_DIR}"
    chmod 700 "${REPOSITORY_PASSWORDS_DIR}"
    (
        umask 077
        printf '%s\n' "${repository_password}" >"${REPOSITORY_PASSWORDS_DIR}/${username}.new"
    )

    mv -fT -- "${REPOSITORY_PASSWORDS_DIR}/${username}.new" "${REPOSITORY_PASSWORDS_DIR}/${username}"

    docker exec "${CONTAINER_NAME}" create_user "${username}" "${rest_password}" >/dev/null

    # Reload now instead of waiting for rest-server's 30-second file check.
    docker kill --signal=HUP "${CONTAINER_NAME}" >/dev/null

    log_success "Created user: ${username}; enter these when the installer asks"
    printf 'rest-server username: %s\nrest-server password: %s\nRepository password: %s\n' \
        "${username}" "${rest_password}" "${repository_password}"
}

main "$@"
