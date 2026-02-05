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

for layer in $(find ${tmp} -name layer.tar); do
    tar -xf $layer -C output
done

# finally include the hypervisor-fw in the image
curl -L -o output/hypervisor-fw https://github.com/cloud-hypervisor/rust-hypervisor-firmware/releases/download/0.4.2/hypervisor-fw
