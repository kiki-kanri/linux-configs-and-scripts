#!/bin/bash

cd "$(dirname "$(readlink -f "$0")")"

if [ "$1" = '-p' ]; then
	docker compose pull
fi

docker compose build && docker compose up -d --remove-orphans
