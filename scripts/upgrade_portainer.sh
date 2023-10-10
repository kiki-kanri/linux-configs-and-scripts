#!/bin/bash

cointainer_name="portainer"

docker pull portainer/portainer-ce:latest || exit 1
[ "$(docker ps | grep $cointainer_name)" ] && docker kill $cointainer_name
[ "$(docker ps -a | grep $cointainer_name)" ] && docker rm $cointainer_name
docker run \
	-d \
	-p 127.0.0.1:9000:9000 \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v portainer_data:/data \
	--name $cointainer_name \
	--restart=always \
	portainer/portainer-ce:latest
