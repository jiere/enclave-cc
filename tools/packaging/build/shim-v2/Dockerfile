ARG GOLANG_BASE=golang:1.19-bullseye
FROM ${GOLANG_BASE} as builder

COPY . .

RUN cd src/shim && \
    make binaries && \
    DESTDIR=/install_root make install

FROM scratch
COPY --from=builder /install_root/bin/* .

# To unpack, it's better to use skopeo+umoci:
# docker build -t shim:devel -f tools/packaging/build/shim-v2/Dockerfile .
# skopeo copy docker-daemon:shim:devel oci:///$PWD/shim-binary:latest
# sudo umoci unpack --image shim-binary:latest shim-binary
# tar -czf shim-v2.tar.gz  -C shim-binary/rootfs .
