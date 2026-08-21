FROM docker.io/library/debian@sha256:34cd9e9fd437c0a095ec39cb2e73422c9f30821b0d0848ed74fd0d43bae4d958

RUN printf '%s\n' 'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/20260820T000000Z trixie main' > /etc/apt/sources.list && \
    rm -f /etc/apt/sources.list.d/debian.sources && \
    apt-get update && apt-get install -y --no-install-recommends \
    bc bison build-essential ca-certificates cpio device-tree-compiler file flex \
    git kmod libelf-dev libncurses-dev libssl-dev python3 rsync squashfs-tools \
    u-boot-tools unzip wget xz-utils && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/x2000-prototype
RUN chmod 0755 /usr/local/bin/x2000-prototype
ENTRYPOINT ["/usr/local/bin/x2000-prototype"]
