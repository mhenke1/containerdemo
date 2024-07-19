# Docker in Go
#work

## Storyboard

### Schritte
##### Intro
1. References
2. Goal
3. Command line

##### Namespaces
1. Start process
2. UTS 
3. Set Hostname
4. Isolate Pid
5. Chroot
6. Mount/ proc

##### Presentation 
More Namespace 

##### Cgroup
1. Define max pods
2. Fork Bomb

#### Set Hostname
`syscall.Sethostname([]byte("container"))`

##### Presentation 
More Cgroups

## Resources

* https://www.infoq.com/articles/build-a-container-golang/
* https://github.com/lizrice/containers-from-scratch/blob/master/main.go
* https://www.youtube.com/watch?v=8fi7uSYlOdc

## Snippets

### Create Filesystem:
```
docker save ubuntu > ubuntu.tar
docker cp ubuntu.tar dockerdemo:/tmp

```
### Container 
#### start container
`docker run --mount type=bind,source=/Users/mhenke/workspace/dev/dockerdemo/main.go,target=/root/main.go --name "dockerdemo7" -h "cloudbb" --cap-add SYS_ADMIN --privileged -i -d dockerdemo:v4`

#### access Container
`docker exec -it dockerdemo7 bash`

### Fork Bomb

* [Wikipedia](https://en.wikipedia.org/wiki/Fork_bomb)
* Code: `:(){ :|:& };:`

### Watch
`watch -n 1 'cat /sys/fs/cgroup/dockerdemo/pids.current'`


### Cloneflags
[clone\(2\) - Linux manual page](https://man7.org/linux/man-pages/man2/clone.2.html)

