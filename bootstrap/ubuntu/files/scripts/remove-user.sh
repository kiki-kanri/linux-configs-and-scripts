#!/usr/bin/env bash

# Usage: sudo bash remove-user.sh ubuntu
# Destructive: --remove-all-files also deletes owned files outside /home.
# References:
# https://manpages.ubuntu.com/manpages/noble/man8/deluser.8.html
# https://www.freedesktop.org/software/systemd/man/latest/loginctl.html

set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'Usage: sudo bash %s USERNAME\n' "$0" >&2
    exit 1
fi

TO_DEL_USER="$1"

# Require a literal username, never a UID, option, or path component.
if [[ ! "${TO_DEL_USER}" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*[$]?$ ]]; then
    printf 'Invalid username: %s\n' "${TO_DEL_USER}" >&2
    exit 1
fi

if ((EUID != 0)); then
    printf 'Run this script as root from another administrator account.\n' >&2
    exit 1
fi

for command in getent loginctl deluser rm groupdel visudo; do
    if ! command -v "${command}" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "${command}" >&2
        exit 1
    fi
done

# Only local accounts can be removed by deluser; do not resolve LDAP/NIS users.
if ! passwd_entry="$(getent --service=files passwd "${TO_DEL_USER}")"; then
    printf 'Local user not found: %s\n' "${TO_DEL_USER}" >&2
    exit 1
fi

IFS=: read -r account_name _ target_uid _ <<<"${passwd_entry}"
if [[ "${account_name}" != "${TO_DEL_USER}" || ! "${target_uid}" =~ ^[0-9]{1,10}$ ]]; then
    printf 'Invalid local passwd entry for: %s\n' "${TO_DEL_USER}" >&2
    exit 1
fi

if ((10#${target_uid} < 1000)); then
    printf 'Refusing to delete %s: UID %s is below 1000.\n' "${TO_DEL_USER}" "${target_uid}" >&2
    exit 1
fi

if [[ "${target_uid}" == "${SUDO_UID:-${EUID}}" ]]; then
    printf 'Refusing to delete the invoking user; use another administrator account.\n' >&2
    exit 1
fi

visudo -c

# Disable lingering first so the user manager will not be kept after logout.
loginctl disable-linger "${TO_DEL_USER}" 2>/dev/null || true
loginctl terminate-user "${TO_DEL_USER}" 2>/dev/null || true

# Do not continue cleanup if account/file removal fails (e.g. remaining processes).
deluser --remove-all-files "${TO_DEL_USER}"

rm -rf -- \
    "/home/${TO_DEL_USER:?}" \
    "/var/mail/${TO_DEL_USER}" \
    "/var/spool/mail/${TO_DEL_USER}" \
    "/var/spool/cron/crontabs/${TO_DEL_USER}" \
    "/etc/sudoers.d/${TO_DEL_USER}" \
    "/etc/sudoers.d/90-${TO_DEL_USER}" \
    "/var/lib/systemd/linger/${TO_DEL_USER}"

# deluser may already have removed the private group; never force group removal.
if getent --service=files group "${TO_DEL_USER}" >/dev/null; then
    groupdel "${TO_DEL_USER}"
fi

visudo -c
