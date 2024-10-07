#! /bin/bash
docker run --name "ubuntusource" -h "ubuntusource" -i -d ubuntu
ID=$(docker ps | grep ubuntusource | cut -d " " -f1)
echo "the container id is $ID"
docker export "$ID" > ubuntu.tar
docker stop "$ID"
docker remove "$ID" 
## "--load" was needed for podman
docker build . -t containerdemo:v1 --load
