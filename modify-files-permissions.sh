#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

git config --replace-all core.filemode true
chmod 700 . -R
find . -type f -exec chmod 600 {} +
find . -name '*.sh' -type f -exec chmod 700 {} +
