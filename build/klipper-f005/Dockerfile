FROM debian:13

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        make \
        gcc \
        git \
        python3 \
        gcc-arm-none-eabi \
        binutils-arm-none-eabi \
        libnewlib-arm-none-eabi \
    && rm -rf /var/lib/apt/lists/*

ENV F005_HOST_X2000_CC=/opt/fre3nder-mips-toolchain/bin/mipsel-buildroot-linux-gnu-gcc

COPY build-x2000-chelper.sh /usr/local/bin/build-x2000-chelper

WORKDIR /work/klipper
