ARG TARGET=base

FROM ubuntu:22.04 as arm-toolchain-downloader

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get install --yes \
        wget \
        xz-utils \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN wget https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz

RUN tar -x -f gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz \
    && rm gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz


FROM ubuntu:22.04 as ax620e-sdk-base

# Fix: https://github.com/hadolint/hadolint/wiki/DL4006
# Fix: https://github.com/koalaman/shellcheck/wiki/SC3014
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get upgrade --yes \
    && apt-get install --yes \
        build-essential \
        zlib1g-dev \
        libncursesw5-dev \
        texinfo \
        texlive \
        gawk \
        libssl-dev \
        openssl \
        bc \
        bison \
        flex \
        u-boot-tools \
        device-tree-compiler \
        gdb \
        u-boot-tools \
        python3-distutils \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3 1

RUN --mount=from=arm-toolchain-downloader,source=/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu,target=/tmp/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu \
    mkdir /usr/local/arm-toolchain/ \
    && cp -r /tmp/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu /usr/local/arm-toolchain/

ENV PATH=$PATH:/usr/local/arm-toolchain/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu/bin

FROM arm-toolchain-downloader as sdk-downloader

COPY AX620E_SDK_V1.7.0_P2_20240130144403_NO19.tgz .

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get install --yes \
        unzip \
        patch \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN tar -x -f AX620E_SDK_V1.7.0_P2_20240130144403_NO19.tgz
RUN rm AX620E_SDK_V1.7.0_P2_20240130144403_NO19.tgz
WORKDIR /AX620E_SDK_V1.7.0_P2_20240130144403_NO19
RUN ./sdk_unpack.sh

FROM ax620e-sdk-base as ax620e-sdk-bsp

RUN --mount=from=sdk-downloader,source=AX620E_SDK_V1.7.0_P2_20240130144403_NO19,target=/tmp/sdk \
    mkdir /opt/AX620E_SDK/ \
    && cd /tmp/sdk/ \
    && cp -r app/ build/ msp/ /opt/AX620E_SDK/

FROM ax620e-sdk-base as ax620e-sdk-full

RUN --mount=from=sdk-downloader,source=AX620E_SDK_V1.7.0_P2_20240130144403_NO19,target=/tmp/sdk \
    mkdir /opt/AX620E_SDK/ \
    && cd /tmp/sdk/ \
    && cp -r app/ boot/ build/ kernel/ msp/ riscv/ rootfs/ /opt/AX620E_SDK/

FROM ax620e-sdk-${TARGET}