#!/bin/bash

# Install nginx

wget -O- https://nginx.org/keys/nginx_signing.key | sudo gpg --dearmor >/usr/share/keyrings/nginx-archive-keyring.gpg &&
	echo deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx | sudo tee /etc/apt/sources.list.d/nginx-stable.list &&
	sudo apt-get update &&
	sudo apt-get install -qy nginx &&

	# Make dhparam.pem
	sudo mkdir -p /etc/nginx/certs &&
	sudo openssl dhparam -dsaparam -out /etc/nginx/certs/dhparam.pem 4096 &&

	# Systemctl
	sudo systemctl enable nginx &&
	sudo systemctl restart nginx
