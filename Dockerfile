FROM ubuntu:24.04@sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac

LABEL org.opencontainers.image.source="https://github.com/mhenke1/containerdemo" \
      org.opencontainers.image.description="Modernized Containerdemo environment (Ubuntu-based)"

# Copy official Go toolchain
COPY --from=golang:1.27.1@sha256:162be5298a40ed317005c8339c6de4d10d3eef336d66dc8e9259b03ab9d3a6d2 /usr/local/go /usr/local/go

ENV PATH=$PATH:/usr/local/go/bin

# Install minimal utilities. No PPA required.
RUN apt-get update && \
    apt-get install -y --no-install-recommends procps vim ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Create marker for host root and prepare inner rootfs directory
RUN touch HOST-ROOT / && mkdir -p /opt/container-filesystem

WORKDIR /opt/container-filesystem

# Copy inner container rootfs archive (Ubuntu)
COPY ubuntu.tar /opt/container-filesystem

# Extract rootfs and add marker inside container root.
# We do not delete ubuntu.tar to ensure the chroot container's ls / output remains unchanged.
RUN tar xf ubuntu.tar && touch CONTAINER-ROOT /opt/container-filesystem

# The demo must run as root to perform namespace, chroot, mount, and cgroup operations.
# USER root

ENV PS1="\h$ "
WORKDIR /root
