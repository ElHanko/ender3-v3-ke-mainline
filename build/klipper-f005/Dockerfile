FROM debian:13

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        make \
        gcc \
        python3 \
        gcc-arm-none-eabi \
        binutils-arm-none-eabi \
        libnewlib-arm-none-eabi \
    && rm -rf /var/lib/apt/lists/*

# Community-hosted distribution of the Ingenic GCC 7.2/glibc 2.29 toolchain
# family used for Creality K1/X2000E builds; the archive origin is not proven
# to be an original Ingenic release artifact.
RUN curl --fail --location --retry 3 --retry-all-errors \
        --output /tmp/mips-gcc720-glibc229.tar.gz \
        https://github.com/ballaswag/k1-discovery/releases/download/1.0.0/mips-gcc720-glibc229.tar.gz \
    && echo 'c0415a857c6b384820ec61b8a30c89e528585f3ef07d580fc856e80313c9d2e8  /tmp/mips-gcc720-glibc229.tar.gz' \
        | sha256sum --check --strict - \
    && tar -xzf /tmp/mips-gcc720-glibc229.tar.gz -C /opt \
    && rm /tmp/mips-gcc720-glibc229.tar.gz

ENV F005_HOST_X2000_TOOLCHAIN=/opt/mips-gcc720-glibc229 \
    F005_HOST_X2000_CC=/opt/mips-gcc720-glibc229/bin/mips-linux-gnu-gcc \
    F005_HOST_X2000_SYSROOT=/opt/mips-gcc720-glibc229/mips-linux-gnu/libc

COPY build-x2000-chelper.sh /usr/local/bin/build-x2000-chelper

WORKDIR /work/klipper
