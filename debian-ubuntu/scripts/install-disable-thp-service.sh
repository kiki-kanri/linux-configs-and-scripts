#!/bin/bash

ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd $ROOT_DIR
. ./scripts/common.sh

sudo cp ./etc/services/disable-thp.service /etc/systemd/system/ &&
	sudo systemctl daemon-reload &&
	sudo systemctl enable disable-thp.service &&
	sudo systemctl start disable-thp.service
