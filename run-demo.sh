#!/usr/bin/env bash
# Starts the demo container with ./main.go mounted at /root/main.go.
# Use ENGINE=podman ./run-demo.sh for Podman.
set -euo pipefail

ENGINE="${ENGINE:-docker}"
DIR="$(cd "$(dirname "$0")" && pwd)"

"$ENGINE" rm -f containerdemo1 >/dev/null 2>&1 || true

# --privileged is the verified minimum (namespaces, chroot, proc mount, cgroup v2 writes).
"$ENGINE" run --mount "type=bind,source=$DIR/main.go,target=/root/main.go" \
  --name containerdemo1 -h containerhost --privileged -i -d containerdemo:v1

echo "attach with: $ENGINE exec -it containerdemo1 bash"
