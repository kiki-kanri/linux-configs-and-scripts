#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# disable-motds.sh — Disable MOTD (Message of the Day) login banners

set -Eeuo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

require_root

chmod -x /etc/update-motd.d/00-header \
    /etc/update-motd.d/10-help-text \
    /etc/update-motd.d/50-landscape-sysinfo \
    /etc/update-motd.d/50-motd-news \
    /etc/update-motd.d/80-edk2-ovmf \
    /etc/update-motd.d/90-updates-available \
    /etc/update-motd.d/91-apt-dracles \
    /etc/update-motd.d/95-hwe-eol \
    /etc/update-motd.d/98-reboot-required
