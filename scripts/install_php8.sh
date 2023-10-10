#!/bin/bash

# Install php8.2

sudo apt-get update &&
	sudo apt-get install apt-transport-https ca-certificates lsb-release software-properties-common &&
	sudo add-apt-repository ppa:ondrej/php &&
	sudo apt-get install php8.2-{bcmath,cli,common,curl,fpm,gd,imap,mbstring,mysql,readline,redis,xml,zip} php8.2 &&
	sudo systemctl enable php8.2-fpm &&
	sudo systemctl start php8.2-fpm
