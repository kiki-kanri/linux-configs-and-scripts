#!/bin/bash

ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd $ROOT_DIR
. ./scripts/common.sh

sudo cp ./etc/update-motd.d/9999-cat /etc/update-motd.d/ &&
	sudo chmod +x /etc/update-motd.d/9999-cat
