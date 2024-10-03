#!/bin/bash

ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd "$ROOT_DIR"
. ./scripts/common.sh

cp ./etc/sysctl.d/disable-ipv6.conf /etc/sysctl.d/ &&
	sudo sysctl --system
