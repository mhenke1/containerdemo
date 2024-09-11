# Containerdemo

An updated version of the "Container in 100 lines of Go demo"
* Based on a blog post from Julian Friedman (Doctor Julz) – 2016 
  * https://www.infoq.com/articles/build-a-container-golang/
* Adopted for a conference talk by Liz Rice - 2018
  * https://github.com/lizrice/containers-from-scratch
  * https://www.youtube.com/watch?v=8fi7uSYlOdc
* Adapted by me to use cgroup v2


## Create the Demo Container 
`./createDemoContainer.sh`

## Run the Demo Container
`docker run --mount type=bind,source=./main.go,target=/root/main.go --name "containerdemo1" -h "demo" --cap-add SYS_ADMIN --privileged -i -d containerdemo:v1`

The go file is mounted in `/root`in the container and can be edited on your host machine in the editor of your choice

## Attach to the Demo Container
`docker exec -it containerdemo1 bash`

## Reset the Show
on your host machine:

`cp Versions/main1.go main.go`

## Run the Show
see `snippets.txt` and the presentation in `/Documentation`
