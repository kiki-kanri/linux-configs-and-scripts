#!/bin/bash

# Install nodejs 22

sudo apt-get update &&
	curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - &&
	sudo apt-get update &&
	sudo apt-get install -qy nodejs &&
	sudo npm upgrade -g &&
	sudo corepack disable pnpm &&
	sudo npm i npm@latest pnpm@latest -g
