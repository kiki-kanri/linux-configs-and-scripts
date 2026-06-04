#!/usr/bin/env bash
# Set hostname and grow root disk space.

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

hostname=""
while [[ -z "${hostname}" ]]; do
    read -r -p "Enter hostname: " hostname </dev/tty
    hostname="${hostname//[[:space:]]/}"
done

hostnamectl set-hostname "${hostname}"
./expand-disk-space.sh
