#!/bin/bash

set -e
exec >/dev/null

openssl dhparam -dsaparam -out /etc/nginx/certs/dhparam.pem 4096
sudo systemctl reload nginx
