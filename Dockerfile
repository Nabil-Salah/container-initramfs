FROM archlinux as builder
RUN pacman -Syu --noconfirm
RUN pacman -S --noconfirm linux mkinitcpio inetutils base-devel bc python3 pahole \
    flex bison elfutils zstd libelf perl openssl cpio
WORKDIR /opt
RUN curl -O https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.tar.xz
RUN tar -xf linux-6.8.tar.xz
COPY config /opt/linux-6.8/.config
WORKDIR /opt/linux-6.8/
RUN make -j $(nproc)
RUN pacman -S --noconfirm openssh
# this is all done later so build goes faster
# if init files has changed, since it's rarely when
# linux build is gonna change

COPY mkinitcpio.conf /root/
COPY initcpio /root/initcpio
COPY heroinit /
# override the original initcpio
COPY init /usr/lib/initcpio
WORKDIR /root
RUN KERNELVERSION=$(ls /lib/modules) mkinitcpio -D /usr/lib/initcpio -D initcpio -v -c mkinitcpio.conf -g initramfs-linux.img

FROM scratch
COPY --from=builder /root/initramfs-linux.img /
COPY --from=builder /opt/linux-6.8/arch/x86/boot/compressed/vmlinux.bin /kernel
