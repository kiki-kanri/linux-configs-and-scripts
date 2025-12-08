#!/bin/bash

set -e

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${SCRIPTS_DIR}"

set +e

git config --replace-all core.filemode true

find . -type d -exec chmod 700 {} \;
find . -type f -exec chmod 600 {} \;

chmod 700 -R ./debian-ubuntu/etc/cron.daily

chmod 700 ./ubuntu/24.04/etc/profile
find . -name '*.bashrc' -exec chmod 700 {} \;
find . -name '*.profile' -exec chmod 700 {} \;
find . -name '*.sh' -exec chmod 700 {} \;
