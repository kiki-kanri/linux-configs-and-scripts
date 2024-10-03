#!/bin/bash

# Install base packages

sudo apt-get update &&
	sudo apt-get install acl curl gcc htop make net-tools perl screen tar tmux unzip vim wget &&
	sudo apt-get autoremove --purge &&
	sudo apt-get autoclean
