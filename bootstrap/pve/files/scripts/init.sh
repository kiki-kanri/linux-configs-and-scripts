#!/usr/bin/env bash
# Set hostname.

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

hostname=""
while [[ -z "${hostname}" ]]; do
    read -r -p "Enter hostname: " hostname </dev/tty
    hostname="${hostname//[[:space:]]/}"
done

hostnamectl set-hostname "${hostname}"
