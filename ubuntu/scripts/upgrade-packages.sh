#!/bin/bash

# Upgrade packages

sudo apt-get update &&
	sudo apt-get upgrade &&
	sudo apt-get autoremove --purge &&
	sudo apt-get autoclean
