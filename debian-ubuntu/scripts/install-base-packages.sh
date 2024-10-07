#!/bin/bash

ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd "$ROOT_DIR"
. ./scripts/common.sh

sudo apt-get update &&
	sudo apt-get install -y acl colormake cron curl g++ gcc htop iftop iotop iputils-ping lsof nmap net-tools perl screen tar tmux unzip vim wget &&
	sudo apt-get autoremove -y --purge &&
	sudo apt-get autoclean
