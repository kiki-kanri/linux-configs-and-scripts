#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${SCRIPTS_DIR}"

# Set hostname
read -rp "Enter hostname: " hostname
hostnamectl set-hostname "${hostname}"

# Expand hard drive
./expand-disk-space.sh
