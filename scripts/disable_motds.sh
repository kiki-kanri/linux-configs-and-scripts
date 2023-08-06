#!/bin/bash

# Disable some motds

cd /etc/update-motd.d &&
	sudo chmod -x 10-help-text 50-landscape-sysinfo 50-motd-news 90-updates-available
