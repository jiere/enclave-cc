FROM ubuntu:20.04
RUN apt update && apt install -y \
    wget gnupg \
    xz-utils \
    ca-certificates curl \
    apt-transport-https && \
    mkdir -p /opt/enclave-cc-artifacts /etc/enclave-cc
WORKDIR /opt/enclave-cc-artifacts
ADD enclave-cc-static.tar.xz .
RUN curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt update && apt install -y kubectl && \
    export KUBECONFIG=/etc/kubernetes/admin.conf

