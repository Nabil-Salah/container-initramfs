FROM ubuntu:24.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Install kernel build dependencies
RUN apt-get update && apt-get install -y \
    fakeroot build-essential ncurses-dev xz-utils \
    libssl-dev bc flex bison libelf-dev \
    cpio zstd curl kmod dwarves python3 \
    busybox-static dosfstools util-linux \
    && rm -rf /var/lib/apt/lists/*

# Download and build kernel
WORKDIR /opt
RUN curl -O https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.tar.xz
RUN tar -xf linux-6.8.tar.xz
COPY config /opt/linux-6.8/.config
WORKDIR /opt/linux-6.8/
RUN make olddefconfig && make -j $(nproc)

# Build initramfs manually using busybox
WORKDIR /root
RUN mkdir -p initramfs/{bin,sbin,etc,proc,sys,dev,new_root,seed,usr/bin,usr/sbin,lib,lib64,hooks}

# Install busybox and create symlinks
RUN cp /bin/busybox initramfs/bin/busybox && \
    cd initramfs/bin && \
    for cmd in sh ash mount umount mkdir cat echo ls cp rm ln sleep seq stat env; do \
        ln -s busybox $cmd; \
    done && \
    cd ../sbin && \
    for cmd in modprobe switch_root; do \
        ln -s ../bin/busybox $cmd; \
    done

# Copy blkid and its dependencies
RUN cp /sbin/blkid initramfs/bin/ && \
    for lib in $(ldd /sbin/blkid 2>/dev/null | grep -o '/lib[^ ]*' | sort -u); do \
        mkdir -p initramfs$(dirname $lib) && \
        cp -L $lib initramfs$lib 2>/dev/null || true; \
    done

# Copy hostname and ping (from busybox)
RUN cd initramfs/bin && ln -s busybox hostname && ln -s busybox ping

# Copy switch_root to /usr/bin (expected by init script)
RUN mkdir -p initramfs/usr/bin && ln -s ../../bin/busybox initramfs/usr/bin/switch_root

# Copy init script, hooks, and binaries
COPY init initramfs/init
COPY init_functions initramfs/init_functions
COPY initcpio/hooks/bootstrap initramfs/hooks/bootstrap
COPY heroinit initramfs/heroinit

# Make everything executable
RUN chmod +x initramfs/init initramfs/init_functions initramfs/heroinit initramfs/hooks/bootstrap initramfs/bin/busybox

# Create config for hooks
RUN echo 'HOOKS="bootstrap"' > initramfs/config && \
    echo 'EARLYHOOKS=""' >> initramfs/config && \
    echo 'LATEHOOKS="bootstrap"' >> initramfs/config && \
    echo 'CLEANUPHOOKS=""' >> initramfs/config && \
    echo 'MODULES=""' >> initramfs/config

# Create the initramfs image (zstd compressed, same as mkinitcpio default)
RUN cd initramfs && \
    find . -print0 | cpio --null --create --format=newc | zstd -19 > /root/initramfs-linux.img

FROM scratch
COPY --from=builder /root/initramfs-linux.img /
COPY --from=builder /opt/linux-6.8/arch/x86/boot/compressed/vmlinux.bin /kernel
