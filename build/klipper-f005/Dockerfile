FROM debian:13

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        make \
        gcc \
        python3 \
        gcc-arm-none-eabi \
        binutils-arm-none-eabi \
        libnewlib-arm-none-eabi \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work/klipper
