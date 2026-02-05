#!env sh
set -e

# Only build if image doesn't exist (allows CI to pre-build with caching)
if ! docker image inspect kernel:latest >/dev/null 2>&1; then
    docker build -t kernel .
fi

mkdir -p output

# Create a temporary container to extract files (use /kernel as dummy command for scratch image)
container_id=$(docker create kernel:latest /kernel)
docker cp ${container_id}:/kernel output/kernel
docker cp ${container_id}:/initramfs-linux.img output/initramfs-linux.img
docker rm ${container_id}

# Verify outputs exist
echo "Output files:"
ls -la output/

# finally include the hypervisor-fw in the image
curl -L -o output/hypervisor-fw https://github.com/cloud-hypervisor/rust-hypervisor-firmware/releases/download/0.4.2/hypervisor-fw
