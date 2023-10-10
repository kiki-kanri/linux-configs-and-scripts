#!/bin/bash

# Install nodejs 20

sudo apt-get update &&
	sudo apt-get install -y ca-certificates curl gnupg &&
	curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg &&
	echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list &&
	sudo apt-get update &&
	sudo apt-get install nodejs &&
	sudo npm i npm@latest -g &&
	sudo npm upgrade -g &&
	sudo corepack enable &&
	sudo corepack install --global pnpm@latest &&
	sudo corepack install --global yarn@stable &&
	corepack install --global pnpm@latest &&
	corepack install --global yarn@stable
