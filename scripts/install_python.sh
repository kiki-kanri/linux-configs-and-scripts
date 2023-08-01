#!/bin/bash

# Install python 3.11.4

sudo add-apt-repository ppa:deadsnakes/ppa -y &&
	sudo apt-get update &&
	sudo apt-get install python3.11 libpython3.11-dev -yq &&
	sudo apt-get reinstall python3-pip -yq &&
	sudo python3.11 -m pip install --upgrade --no-cache-dir pip setuptools wheel &&
	sudo python3.11 -m pip cache purge
