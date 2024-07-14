#!/bin/bash

# Copy cat motd to /etc/update-motd.d

cd $(dirname "$(readlink -f "$0")")
sudo cp ../configs/update-motd.d/9999-cat /etc/update-motd.d/
sudo chmod +x /etc/update-motd.d/9999-cat
