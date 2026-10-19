#!/usr/bin/env bash
# Exports an Ubuntu root filesystem to ubuntu.tar and builds the demo image.
# Use ENGINE=podman ./createDemoContainer.sh for Podman.
set -euo pipefail

ENGINE="${ENGINE:-docker}"
cd "$(dirname "$0")"

# Remove the temporary container on exit, also after a failure.
cleanup() { "$ENGINE" rm -f ubuntusource >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup # leftover from a previous failed run

# A created (never started) container is enough to export its filesystem.
"$ENGINE" create --name ubuntusource -h ubuntusource ubuntu:24.04 >/dev/null
"$ENGINE" export ubuntusource > ubuntu.tar

# No "--load": a plain build already stores the image locally (also with Podman).
"$ENGINE" build . -t containerdemo:v1
