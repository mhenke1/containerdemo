# Containerdemo

An updated version of the "Container in (about) 100 lines of Go demo"
* Based on a blog post from Julian Friedman (Doctor Julz) – 2016 
  * https://www.infoq.com/articles/build-a-container-golang/
* Adopted for a conference talk by Liz Rice - 2018
  * https://github.com/lizrice/containers-from-scratch
  * https://www.youtube.com/watch?v=8fi7uSYlOdc
* Adapted by me to use cgroup v2


## Prerequisites
* Docker (or Podman, untested)
* Linux host with cgroup v2 enabled, or Docker Desktop VM on macOS / Windows
* Internet access during image build (to pull base images)


## Create the Demo Container 
`./createDemoContainer.sh`


## Run the Demo Container
Use the wrapper script (handles absolute paths and cleans up an old container):

`./run-demo.sh`

Or run directly with Docker (source must be an absolute path):

`docker run --mount type=bind,source="$(pwd)/main.go",target=/root/main.go --name "containerdemo1" -h "containerhost" --privileged -i -d containerdemo:v1`

The go file is mounted in `/root` in the container and can be edited on your host machine in the editor of your choice.

`ENGINE=podman ./run-demo.sh` is provided for Podman but is untested (Podman machine was not running during development; rootless Podman is likely unsupported).


## Notes
- Root and `--privileged` are required: the demo creates Linux namespaces, calls `chroot`, mounts `proc`, and writes cgroup v2 controller files. Without `--privileged`, Docker mounts `/sys/fs/cgroup` read-only and its default AppArmor profile blocks namespace creation — `--cap-add SYS_ADMIN` alone is not enough. This was confirmed by testing on Docker 29 with cgroup v2; no narrower combination of `--cap-add`, `--cgroupns`, `--security-opt`, or bind-mounting the cgroup fs was sufficient.
- Run this only on a disposable local machine or VM — not on a shared or production host.
- Tested on Docker 29.2.1 with cgroup v2 (arm64 macOS). Podman is untested; rootless Podman is likely unsupported.
- `./createDemoContainer.sh` builds the image. It also supports `ENGINE=podman ./createDemoContainer.sh`.


## Attach to the Demo Container
`docker exec -it containerdemo1 bash`


## Reset the Show
On your host machine:

`cp Versions/main1.go main.go`

Because `main.go` is bind-mounted into `/root/main.go`, changes on the host are picked up live inside the running container.


## Run the Show
Follow the step-by-step code progression in `snippets.txt` and the presentation notes in [`Documentation/`](Documentation).

During the step 8 cgroup demo, check active process limits in a second shell with:

`watch -n 1 'cat /sys/fs/cgroup/containerdemo/pids.current'`


## Troubleshooting
* **Permission denied on `/proc/self/exe` or read-only `/sys/fs/cgroup`:**
  The container was started without `--privileged`. Docker blocks namespace creation and mounts `/sys/fs/cgroup` as read-only by default (see [Notes](#notes)).
* **"domain invalid" / `EOPNOTSUPP` or missing `pids.max`:**
  Ensure cgroup v2 is enabled on the host or VM. In containerized environments, cgroup v2 requires writing `+pids` to parent `cgroup.subtree_control` and using `threaded` mode (handled in `main8.go`).
* **Container name conflict (`containerdemo1` already exists):**
  Handled automatically by `./run-demo.sh`, or remove manually via `docker rm -f containerdemo1`.
* **Stale `/sys/fs/cgroup/containerdemo` directory:**
  Cleaned up automatically when `main8.go` exits; existing directories on start are handled gracefully with `os.IsExist`.


## Further Reading
The following topics are real-world container mechanisms **not** implemented in this simplified educational demo:
* **`pivot_root(2)`:** Safely swaps root filesystems and detaches old host mounts ([pivot_root(2) man page](https://man7.org/linux/man-pages/man2/pivot_root.2.html)).
* **User namespaces:** Maps container root to an unprivileged host user ([user_namespaces(7) man page](https://man7.org/linux/man-pages/man7/user_namespaces.7.html)).
* **Network namespaces:** Configures isolated virtual network interfaces and routing ([network_namespaces(7) man page](https://man7.org/linux/man-pages/man7/network_namespaces.7.html)).
* **Linux namespaces overview:** [namespaces(7) man page](https://man7.org/linux/man-pages/man7/namespaces.7.html).
* **Control groups overview:** [cgroups(7) man page](https://man7.org/linux/man-pages/man7/cgroups.7.html).
* **`clone(2)` system call:** [clone(2) man page](https://man7.org/linux/man-pages/man2/clone.2.html).
* **OCI Runtime Specification:** [opencontainers/runtime-spec](https://github.com/opencontainers/runtime-spec).
