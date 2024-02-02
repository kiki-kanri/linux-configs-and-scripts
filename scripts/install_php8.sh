#!/bin/bash

# Install php8.3

sudo apt-get update &&
	sudo apt-get install apt-transport-https ca-certificates lsb-release software-properties-common &&
	sudo add-apt-repository ppa:ondrej/php &&
	sudo apt-get install php8.3-{bcmath,cli,common,curl,fpm,gd,imap,mbstring,mysql,readline,redis,xml,zip} php8.3 &&
	sudo systemctl enable php8.3-fpm &&
	sudo systemctl start php8.3-fpm
