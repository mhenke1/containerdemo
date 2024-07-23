# Containerdemo


## Create Demo Container 
`./Users/mhenke/workspace/dev/containerdemo/createDemoContainer.sh`

## Run the Container
`docker run --mount type=bind,source=/Users/mhenke/workspace/dev/containerdemo/main.go,target=/root/main.go --name "containerdemo1" -h "demo" --cap-add SYS_ADMIN --privileged -i -d containerdemo:v1`

## Attach to the container
`docker exec -it containerdemo1 bash`

## prepare the show
`cp Versions/main1.go main.go`

## run teh show
see `snippets.txt`