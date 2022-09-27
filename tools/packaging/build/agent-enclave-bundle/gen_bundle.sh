#!/bin/bash
set -e

if [ ! -n "$1" ] ;then
    echo "error: missing input parameter, please input image tag, such as zhiwei/occlum-enclave-agent-app:v1.0."
    exit 1
fi

#if image $1 exist, romove it.
sudo docker rmi $1 -f

docker build . -t $1

agentContainerPath="${PAYLOAD_ARTIFACTS}/agent-instance"
if [ ! -d "$agentContainerPath" ]; then
  sudo mkdir -p $agentContainerPath
fi

pushd $agentContainerPath

sudo cp ${SCRIPT_ROOT}/agent-enclave-bundle/config.json .

sudo rm -rf rootfs && sudo mkdir rootfs

sudo docker export $(docker create $1) | sudo tar -C rootfs -xvf -

popd
