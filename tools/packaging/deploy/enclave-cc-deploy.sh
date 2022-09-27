#!/usr/bin/env bash
# Copyright (c) 2022 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

set -o errexit
set -o pipefail
set -o nounset

containerd_conf_file="/etc/containerd/config.toml"
containerd_conf_file_backup="${containerd_conf_file}.bak"

shim_rune_binary="containerd-shim-rune-v2"
install_path="/usr/local/bin"

# If we fail for any reason a message will be displayed
die() {
        msg="$*"
        echo "ERROR: $msg" >&2
        exit 1
}

function print_usage() {
	echo "Usage: $0 [install/cleanup/reset]"
}

function get_container_runtime() {

	local runtime=$(kubectl get node $NODE_NAME -o jsonpath='{.status.nodeInfo.containerRuntimeVersion}')
	if [ "$?" -ne 0 ]; then
                die "invalid node name"
	fi
	if echo "$runtime" | grep -qE 'containerd.*-k3s'; then
		if systemctl is-active --quiet rke2-agent; then
			echo "rke2-agent"
		elif systemctl is-active --quiet rke2-server; then
			echo "rke2-server"
		elif systemctl is-active --quiet k3s-agent; then
			echo "k3s-agent"
		else
			echo "k3s"
		fi
	else
		echo "$runtime" | awk -F '[:]' '{print $1}'
	fi
}

function install_artifacts() {
	echo "copying enclave-cc artifacts onto host"
	cp -a /opt/enclave-cc-artifacts/* /opt/enclave-cc/
	mv /opt/enclave-cc/shim-rune-config.toml /etc/enclave-cc/config.toml
	install -d $install_path
	install -D -m0755 /opt/enclave-cc/${shim_rune_binary} $install_path
	echo "deb [arch=amd64 signed-by=/usr/share/keyrings/occlum.gpg] http://mirrors.openanolis.cn/inclavare-containers/ubuntu20.04 focal main" | tee -a /etc/apt/sources.list.d/occlum.list
	wget -qO - http://mirrors.openanolis.cn/inclavare-containers/ubuntu20.04/DEB-GPG-KEY.key | gpg --dearmor --output /usr/share/keyrings/occlum.gpg
	apt update
	env DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends occlum-runtime occlum-toolchains-glibc occlum rune
}

function configure_cri_runtime() {
	case $1 in
	containerd | k3s | k3s-agent | rke2-agent | rke2-server)
		configure_containerd
		;;
	esac
	systemctl daemon-reload
	systemctl restart "$1"
}

function configure_containerd() {
	# Configure containerd to use enclave-cc:
	echo "Add enclave-cc as a supported runtime for containerd"

	mkdir -p /etc/containerd/

	if [ -f "$containerd_conf_file" ]; then
		# backup the config.toml only if a backup doesn't already exist (don't override original)
		cp -n "$containerd_conf_file" "$containerd_conf_file_backup"
	fi

	configure_containerd_runtime
}

function configure_containerd_runtime() {
	# currently the runtime name is still "rune".
	local runtime="rune"
	local pluginid=cri
	if grep -q "version = 2\>" $containerd_conf_file; then
		pluginid=\"io.containerd.grpc.v1.cri\"
	fi
	local runtime_table="plugins.${pluginid}.containerd.runtimes.enclave-cc"
	local runtime_type="io.containerd.$runtime.v2"
	if grep -q "\[$runtime_table\]" $containerd_conf_file; then
		echo "Configuration exists for $runtime_table, overwriting"
		sed -i "/\[$runtime_table\]/,+1s#runtime_type.*#runtime_type = \"${runtime_type}\"#" $containerd_conf_file
	else
		cat <<EOF | tee -a "$containerd_conf_file"
[$runtime_table]
  cri_handler = "cc"
  runtime_type = "${runtime_type}"
EOF
	fi
}

function remove_artifacts() {
	echo "deleting enclave-cc artifacts"
	rm -rf /opt/enclave-cc
	rm ${install_path}/{shim_rune_binary} 
	apt remove -y occlum-runtime rune
}

function cleanup_cri_runtime() {
	# currently only support containerd
	cleanup_containerd
}

function cleanup_containerd() {
	rm -f $containerd_conf_file
	if [ -f "$containerd_conf_file_backup" ]; then
		mv "$containerd_conf_file_backup" "$containerd_conf_file"
	fi
}

function reset_runtime() {
	kubectl label node "$NODE_NAME" confidentialcontainers.org/enclave-cc=
	systemctl daemon-reload
	systemctl restart "$1"
	systemctl restart kubelet
}

function main() {
	# script requires that user is root
	euid=$(id -u)
	if [[ $euid -ne 0 ]]; then
	   die  "This script must be run as root"
	fi

	runtime=$(get_container_runtime)
	if [ "$runtime" != "containerd" ]; then
		die "$runtime is not supported for now"
	fi

	if [ ! -f "$containerd_conf_file" ] && [ -d $(dirname "$containerd_conf_file") ] && \
		[ -x $(command -v containerd) ]; then
		containerd config default > "$containerd_conf_file"
	fi

	action=${1:-}
	if [ -z "$action" ]; then
		print_usage
		die "invalid arguments"
	fi

	case "$action" in
	install)
		install_artifacts
		configure_cri_runtime "$runtime"
		kubectl label node "$NODE_NAME" --overwrite confidentialcontainers.org/enclave-cc=true
		;;
	cleanup)
		cleanup_cri_runtime "$runtime"
		kubectl label node "$NODE_NAME" --overwrite confidentialcontainers.org/enclave-cc=cleanup
		remove_artifacts
		;;
	reset)
		reset_runtime $runtime
		;;
	*)
		echo invalid arguments
		print_usage
		;;
	esac

	#It is assumed this script will be called as a daemonset. As a result, do
        # not return, otherwise the daemon will restart and rexecute the script
	sleep infinity
}

main "$@"

