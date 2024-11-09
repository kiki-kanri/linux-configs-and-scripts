#!/bin/bash

cd "$(dirname "$(readlink -f "$0")")"

if [ "$1" = '-p' ]; then
	docker compose pull
fi

gcc -march=native -fPIC -pthread -O3 -shared -Werror=format-security -Wformat -o ./libforce_enable_thp.so ./force_enable_thp.c -ldl -lpthread &&
	docker compose build && docker compose up -d --remove-orphans
