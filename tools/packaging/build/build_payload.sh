#!/bin/bash
set -e

docker rmi $1 -f

export SCRIPT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export ENCLAVE_CC_ROOT="${SCRIPT_ROOT}/../../../"

rm -rf payload_artifacts && mkdir -p payload_artifacts/scripts
export PAYLOAD_ARTIFACTS="${SCRIPT_ROOT}/payload_artifacts"

# build pre-installed OCI bundle for agent enclave container
pushd ${SCRIPT_ROOT}/agent-enclave-bundle
./gen_bundle.sh agent_enclave_container
popd

# build pre-installed OCI bundle for boot instance
pushd ${SCRIPT_ROOT}/boot-instance-bundle
./gen_bundle.sh app_enclave_container
popd

# build shim-rune binary: "containerd-shim-rune-v2"
pushd ${ENCLAVE_CC_ROOT}/src/shim
make binaries
cp ./bin/containerd-shim-rune-v2 ${PAYLOAD_ARTIFACTS}
popd

# rune binary will be installed directly through "apt install" inside the docker build.

cp ${SCRIPT_ROOT}/../deploy/enclave-cc-deploy.sh ${PAYLOAD_ARTIFACTS}/scripts

# prepare payload artifacts static tarball
pushd $PAYLOAD_ARTIFACTS

tar cfJ enclave-cc-static.tar.xz *

cat >Dockerfile <<EOF
FROM ubuntu:20.04
RUN apt update && apt install -y xz-utils && mkdir -p /opt/enclave-cc-artifacts
WORKDIR /opt/enclave-cc-artifacts
ADD enclave-cc-static.tar.xz .
EOF
docker build . -t $1

popd

#cleanup
rm -rf payload_artifacts

