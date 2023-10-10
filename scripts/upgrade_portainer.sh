#!/bin/bash

container_name="portainer"

docker pull portainer/portainer-ce:latest || exit 1
[ "$(docker ps | grep $container_name)" ] && docker kill $container_name
[ "$(docker ps -a | grep $container_name)" ] && docker rm $container_name
docker run \
	-d \
	-p 127.0.0.1:9000:9000 \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v portainer_data:/data \
	--name $container_name \
	--restart=always \
	portainer/portainer-ce:latest
