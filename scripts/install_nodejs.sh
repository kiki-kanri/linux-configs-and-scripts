#!/bin/bash

# Install nodejs 20

curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - &&
	sudo apt-get update &&
	sudo apt-get install nodejs &&
	sudo npm i npm@latest -g &&
	sudo corepack enable &&
	sudo corepack prepare pnpm@latest --activate
