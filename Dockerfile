FROM docker/for-desktop-kernel:5.10.104-ad41e9402fa6e51d2635fb92e4cb6b90107caa25 as ksrc

FROM alpine:latest AS build
WORKDIR /tmp/linux-src
COPY --from=ksrc /kernel-dev.tar /tmp/linux-src

RUN apk add --no-cache --update ca-certificates libc-dev linux-headers libressl-dev elfutils-dev curl gcc bison flex make musl-dev mpfr-dev mpc1-dev gmp-dev g++ \
    && KERNELVER=$(uname -r  | cut -d '-' -f 1)   \
    && curl -fsSL https://www.kernel.org/pub/linux/kernel/v${KERNELVER%%.*}.x/linux-$(uname -r | cut -d '-' -f 1).tar.gz | tar -xzf - --strip-components=1 \
    && tar xf kernel-dev.tar \
    && make defconfig \
    && ([ ! -f /proc/1/root/proc/config.gz ] || zcat /proc/1/root/proc/config.gz > .config) \
    && printf '%s\n' 'CONFIG_USBIP_CORE=m' 'CONFIG_USBIP_VHCI_HCD=m' 'CONFIG_USBIP_VHCI_HC_PORTS=8' 'CONFIG_USBIP_VHCI_NR_HCS=1' >> .config \
    && make oldconfig modules_prepare \
    && make -j$(nproc) M=drivers/usb/usbip \
    && mkdir -p /dist \
    && cd drivers/usb/usbip \
    && cp usbip-core.ko vhci-hcd.ko /dist \
    && echo -e '[General]\nAutoFind=0\n' > /dist/.vhui \
    && curl -fsSL https://www.virtualhere.com/sites/default/files/usbclient/vhclientx86_64 -o /dist/vhclientx86_64 \
    && curl -fsSL https://www.virtualhere.com/sites/default/files/usbclient/vhclientarm64 -o /dist/vhclientarm64 \
    && chmod +x /dist/vhclientx86_64 /dist/vhclientarm64

FROM alpine
COPY --from=build /dist/* /vhclient/
ENV HOME=/vhclient
WORKDIR /vhclient
