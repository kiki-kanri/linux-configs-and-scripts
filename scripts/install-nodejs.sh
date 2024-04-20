#!/bin/bash

# Install nodejs 21

sudo apt-get update &&
	curl -fsSL https://deb.nodesource.com/setup_21.x | sudo -E bash - &&
	sudo apt-get update &&
	sudo apt-get install -qy nodejs &&
	sudo npm i npm@latest -g &&
	sudo npm upgrade -g &&
	sudo corepack enable &&
	sudo corepack install --global pnpm@latest &&
	sudo corepack install --global yarn@stable &&
	corepack install --global pnpm@latest &&
	corepack install --global yarn@stable
