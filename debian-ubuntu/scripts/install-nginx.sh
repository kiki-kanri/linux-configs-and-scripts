#!/bin/bash

ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd $ROOT_DIR
. ./scripts/common.sh

if [ "$os_type" = 'debian' ]; then
	to_install_packages='ca-certificates curl debian-archive-keyring gnupg2 lsb-release'
elif [ "$os_type" = 'ubuntu' ]; then
	to_install_packages='ca-certificates curl gnupg2 lsb-release ubuntu-keyring'
fi

sudo apt-get install -qy $to_install_packages &&
	curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null &&
	echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] "http://nginx.org/packages/$os_type" $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list &&
	sudo apt-get update &&
	sudo apt-get install -qy nginx &&

	# Configure nginx
	sudo mkdir -p /etc/nginx/certs &&
	sudo openssl dhparam -dsaparam -out /etc/nginx/certs/dhparam.pem 4096 &&
	sudo rm -rf /etc/nginx/nginx.conf &&
	cd $ROOT_DIR &&
	sudo cp -r ./etc/nginx /etc/ &&
	sudo systemctl enable nginx &&
	sudo systemctl restart nginx
