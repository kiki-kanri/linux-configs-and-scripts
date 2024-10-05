#!/bin/bash

openssl dhparam -dsaparam -out /etc/nginx/certs/dhparam.pem 4096 &&
	systemctl nginx reload
