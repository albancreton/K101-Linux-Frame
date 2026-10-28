FROM debian:trixie

RUN apt-get update && apt-get install -y --no-install-recommends \
        bc bison build-essential ca-certificates cpio device-tree-compiler \
        flex gcc-arm-linux-gnueabihf git kmod libelf-dev libgnutls28-dev \
        libssl-dev python3 python3-dev python3-libfdt python3-pyelftools \
        python3-setuptools rsync swig u-boot-tools uuid-dev \
        mmdebstrap arch-test e2fsprogs libarchive13t64 dosfstools mtools \
    && rm -rf /var/lib/apt/lists/*

ENV CROSS_COMPILE=arm-linux-gnueabihf- ARCH=arm LANG=C.UTF-8
WORKDIR /work
