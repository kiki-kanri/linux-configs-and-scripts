#!/bin/bash

ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd $ROOT_DIR
. ./scripts/common.sh

sudo apt-get update &&
	sudo apt-get install apt-transport-https ca-certificates lsb-release software-properties-common &&
	sudo add-apt-repository ppa:ondrej/php &&
	sudo apt-get install php8.3 php8.3-{bcmath,cli,common,curl,fpm,gd,imap,mbstring,mysql,readline,redis,xml,zip} &&
	sudo systemctl enable php8.3-fpm &&
	sudo systemctl start php8.3-fpm
