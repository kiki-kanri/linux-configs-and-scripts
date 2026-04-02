#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
# modify-files-permissions.sh — Fix file permissions for linux-configs-and-scripts
#
# Sets restrictive permissions (600 for files, 700 for dirs) and configures
# git filemode before git clone. Run this before anything else in bootstrap.

set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

set +e

git config --replace-all core.filemode true

find . -type d -exec chmod 700 {} \;
find . -type f -exec chmod 600 {} \;
find . -name '*.bashrc' -exec chmod 700 {} \;
find . -name '*.profile' -exec chmod 700 {} \;
find . -name '*.sh' -exec chmod 700 {} \;

chmod 700 -R \
    ./bootstrap/ubuntu/files/etc/skel \
    ./bootstrap/ubuntu/files/etc/bash.bashrc \
    ./bootstrap/ubuntu/files/etc/profile \
    ./bootstrap/ubuntu/files/root
