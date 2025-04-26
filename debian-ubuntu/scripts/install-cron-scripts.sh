#!/bin/bash

set -e

ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd "$ROOT_DIR"
. ./scripts/common.sh

for file in ./etc/cron.daily/*; do
    filename=$(basename "$file")
    read -p "Do you want to install $filename? (y/n) [y]: " choice
    choice=${choice:-y}
    case "$choice" in
    [Yy]*)
        cp -f "$file" /etc/cron.daily/
        chmod 700 "/etc/cron.daily/$filename"
        chown root:root "/etc/cron.daily/$filename"
        echo "$filename installed."
        ;;
    [Nn]*)
        echo "$filename not installed."
        ;;
    *)
        echo "Invalid choice. $filename not installed."
        ;;
    esac
done
