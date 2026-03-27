#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${SCRIPTS_DIR}"

# Set hostname
read -rp "Enter hostname: " HOSTNAME
hostnamectl set-hostname "${HOSTNAME}"

# Expand hard drive
./expand-disk-space.sh
