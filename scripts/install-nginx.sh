#!/bin/bash

# Install nginx

cd $(dirname "$(readlink -f "$0")")
sudo apt-get install -qy ca-certificates curl gnupg2 lsb-release ubuntu-keyring &&
	curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg &&
	gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg &&
	echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list &&
	sudo apt-get update &&
	sudo apt-get install -qy nginx &&

	# Make dhparam.pem
	sudo mkdir -p /etc/nginx/certs &&
	sudo openssl dhparam -dsaparam -out /etc/nginx/certs/dhparam.pem 4096 &&

	# Copy nginx file
	sudo rm -rf /etc/nginx/nginx.conf &&
	cd ../configs/nginx &&
	sudo cp -r ./domains ./public ./nginx.conf /etc/nginx/ &&

	# Systemctl
	sudo systemctl enable nginx &&
	sudo systemctl restart nginx
