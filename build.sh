#!env sh
set +e

strip heroinit

# Only build if image doesn't exist (allows CI to pre-build with caching)
if ! docker image inspect kernel:latest >/dev/null 2>&1; then
    docker build -t kernel .
fi

tmp=$(mktemp -d)
cleanup() {
    rm -rf ${tmp}
}

trap cleanup EXIT
docker save kernel | tar -x -C ${tmp}
mkdir -p output || true

# Extract all layers to a temp location first
extract_dir=$(mktemp -d)
for layer in $(find ${tmp} -name layer.tar); do
    tar -xf $layer -C ${extract_dir}
done

# Copy the specific files we need
cp ${extract_dir}/kernel output/kernel
cp ${extract_dir}/initramfs-linux.img output/initramfs-linux.img

rm -rf ${extract_dir}

# finally include the hypervisor-fw in the image
curl -L -o output/hypervisor-fw https://github.com/cloud-hypervisor/rust-hypervisor-firmware/releases/download/0.4.2/hypervisor-fw
