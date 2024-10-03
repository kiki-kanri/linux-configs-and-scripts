#!/bin/bash

# Install and enable disable-thp service

cd $(dirname "$(readlink -f "$0")")
sudo cp ../configs/services/disable-thp.service /etc/systemd/system/ &&
	sudo systemctl daemon-reload &&
	sudo systemctl enable disable-thp.service &&
	sudo systemctl start disable-thp.service
