#!/bin/bash
set -e

if [ ! -n "$1" ] ;then
echo "error: missing input parameter, please input image tag, such as
zhiwei/app-enclave:v1.0."
exit 1
fi

#if image $1 exist, romove it.
sudo docker rmi $1 -f

docker build . -t $1

bootContainerPath="${PAYLOAD_ARTIFACTS}/boot-instance"
if [ ! -d "$bootContainerPath" ]; then
    sudo mkdir -p $bootContainerPath
fi

pushd $bootContainerPath
sudo rm -rf rootfs && sudo mkdir rootfs
sudo docker export $(docker create $1) | sudo tar -C rootfs -xvf -

sudo mkdir -p rootfs/sefs/lower
sudo mkdir -p rootfs/sefs/upper
popd
