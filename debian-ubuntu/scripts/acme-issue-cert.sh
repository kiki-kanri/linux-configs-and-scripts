#!/bin/bash

read -p '請輸入 Cloudflare帳號id: ' CF_Account_ID
read -p '請輸入 Cloudflare區域id: ' CF_Zone_ID
read -p '請輸入 Cloudflare token: ' CF_Token
read -p '請輸入domain: ' ISSUE_DOMAIN

export CF_Account_ID
export CF_Zone_ID
export CF_Token

/root/.acme.sh/acme.sh --issue --dns dns_cf -d $ISSUE_DOMAIN -d *.$ISSUE_DOMAIN -k 4096 &&
	echo 'Wait 15 seconds...' &&
	sleep 15 &&
	/root/.acme.sh/acme.sh --issue --dns dns_cf -d $ISSUE_DOMAIN -d *.$ISSUE_DOMAIN -k ec-384 &&
	mkdir -p /etc/nginx/certs/$ISSUE_DOMAIN/ecc &&
	mkdir -p /etc/nginx/certs/$ISSUE_DOMAIN/rsa &&

	#
	/root/.acme.sh/acme.sh --install-cert -d $ISSUE_DOMAIN \
		--cert-file /etc/nginx/certs/$ISSUE_DOMAIN/rsa/cert.pem \
		--key-file /etc/nginx/certs/$ISSUE_DOMAIN/rsa/private.key \
		--fullchain-file /etc/nginx/certs/$ISSUE_DOMAIN/rsa/fullchain.pem \
		--ca-file /etc/nginx/certs/$ISSUE_DOMAIN/rsa/chain.pem \
		--reloadcmd 'sudo systemctl reload nginx' &&

	#
	/root/.acme.sh/acme.sh --install-cert -d $ISSUE_DOMAIN --ecc \
		--cert-file /etc/nginx/certs/$ISSUE_DOMAIN/ecc/cert.pem \
		--key-file /etc/nginx/certs/$ISSUE_DOMAIN/ecc/private.key \
		--fullchain-file /etc/nginx/certs/$ISSUE_DOMAIN/ecc/fullchain.pem \
		--reloadcmd 'sudo systemctl reload nginx'
