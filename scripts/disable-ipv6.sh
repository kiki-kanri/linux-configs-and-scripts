#!/bin/bash

# Disable ipv6

echo "
# Disable ipv6
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
" | sudo tee /etc/sysctl.d/disable-ipv6.conf
sudo sysctl -p
