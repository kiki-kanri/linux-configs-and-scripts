#!/bin/bash

ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd "$ROOT_DIR"
. ./scripts/common.sh

cd /etc/update-motd.d &&
	sudo chmod -x 10-help-text 50-landscape-sysinfo 50-motd-news 90-updates-available
