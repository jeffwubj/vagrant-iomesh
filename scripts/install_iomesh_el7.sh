#!/usr/bin/env bash


# Copyright (C) 2021 IOMesh
# All rights reserved.

# install_iomesh.sh: install iomesh in your kubernetes cluster

# You must be prepared as follows before run install_iomesh.sh:
#
# 1. IOMESH_DATA_CIDR MUST be set as environment variable, According to the
#    network environment of your k8s cluster, for an example:
#
#        export IOMESH_DATA_CIDR=192.168.1.0/20
#
#    See more detail about IOMESH_DATA_CIDR in http://iomesh.com/docs/next/installation/setup-iomesh-storage
#
# 2. Since IOMesh relies on some mirrors from docker.io, gcr.io, quay.io, etc.
#    if it is the first time to install IOMesh, your network environment MUST
#    be able to access these websites quickly
#

readonly IOMESH_DATA_CIDR="10.0.0.0/24"

readonly IOMESH_OPERATOR_NAMESPACE="iomesh-system"
readonly IOMESH_OPERATOR_CHART="iomesh/operator"
readonly IOMESH_OPERATOR_RELEASE="operator"

readonly IOMESH_NAMESPACE="iomesh-system"
readonly IOMESH_CHART="iomesh/iomesh"
readonly IOMESH_RELEASE="iomesh"

readonly IOMESH_CSI_NAMESPACE="iomesh-system"
readonly IOMESH_CSI_CHART="iomesh/csi-driver"
readonly IOMESH_CSI_RELEASE="csi-driver"
readonly MOUNT_ISCSI_LOCK="false"

readonly ZK_REPLICAS=1
readonly META_REPLICAS=1
readonly CHUNK_REPLICAS=3
readonly CSI_CONTROLLER_REPLICAS=1

readonly TIME_OUT_SECOND=600s # 600s

INSTALL_LOG_PATH=""


info() {
	echo "[Info][$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" | tee -a ${INSTALL_LOG_PATH}
}

error() {
        echo "[Error][$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" | tee -a ${INSTALL_LOG_PATH}
        exit 1
}

install_snapshot_controller() {
	# if snapshot-controller already installed, just return
	if kubectl get statefulset snapshot-controller -n kube-system &> /dev/null ; then
		return
	fi
	info "Install snapshot controller..."

	if ! curl -LOs https://github.com/kubernetes-csi/external-snapshotter/archive/release-2.1.tar.gz ; then
		error "Fail to download external-snapshotter, please confirm whether the connection to github.com is ok?"
	fi
	tar -xf release-2.1.tar.gz &> /dev/null
	kubectl create -f external-snapshotter-release-2.1/config/crd
	sed -i  "s/namespace:\ default/namespace:\ kube-system/g" external-snapshotter-release-2.1/deploy/kubernetes/snapshot-controller/*
	kubectl apply -f external-snapshotter-release-2.1/deploy/kubernetes/snapshot-controller -n kube-system
	# TODO(ziyin): ensure snapshot-controller container pull success
	info "Snapshot controller install completed"
}

install_kubectl() {
	info "Install kubectl..."
	if ! curl -LOs "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" ; then
		error "Fail to get kubectl, please confirm whether the connection to dl.k8s.io is ok?"
	fi
	if ! sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl ; then
		error "Install kubectl fail"
	fi
	info "Kubectl install completed"
}

install_helm() {
	info "Install helm..."
	if ! curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 ; then
		error "Fail to get helm installed script, please confirm whether the connection to raw.githubusercontent.com is ok?"
	fi
	chmod 700 get_helm.sh
	if ! ./get_helm.sh ; then
		error "Fail to get helm when running get_helm.sh"
	fi
	info "Helm install completed"
}

verify_supported() {
	HAS_HELM="$(type "helm" &> /dev/null && echo true || echo false)"
	HAS_KUBECTL="$(type "kubectl" &> /dev/null && echo true || echo false)"
	HAS_CURL="$(type "curl" &> /dev/null && echo true || echo false)"

	if  [[ -z "${IOMESH_DATA_CIDR}" ]] ; then
		error "IOMESH_DATA_CIDR MUST set in environment variable."
	fi

	if  [[ ! "${IOMESH_DATA_CIDR}" =~ ^([0-9]+\.){3}([0-9]+)/([0-9]+)$ ]] ; then
		error "IOMESH_DATA_CIDR is not the correct cidr format. example: IOMESH_DATA_CIDR=192.168.1.0/24"
	fi

	if [[ "${HAS_CURL}" != "true" ]]; then
		error "curl is required"
	fi

	if [[ "${HAS_HELM}" != "true" ]]; then
		install_helm
	fi

	if [[ "${HAS_KUBECTL}" != "true" ]]; then
		install_kubectl
	fi
}

install_iomesh_operator() {
	# check if operator already installed
	if helm status ${IOMESH_OPERATOR_RELEASE} -n ${IOMESH_OPERATOR_NAMESPACE} &> /dev/null ; then
		error "IOMesh operator already installed. Use helm remove it first"
	fi
	info "Install IOMesh operator, It might take a long time..."
	helm install ${IOMESH_OPERATOR_RELEASE} ${IOMESH_OPERATOR_CHART} \
	  --atomic \
	  --debug  \
	  --namespace ${IOMESH_OPERATOR_NAMESPACE} \
	  --create-namespace \
	  --timeout $TIME_OUT_SECOND \
	  --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a ${INSTALL_LOG_PATH}
	if [[ $? -ne 0 ]] ; then
		error "Fail to install IOMesh operator."
	fi
}

install_iomesh() {
	# check if iomesh already installed
	if helm status ${IOMESH_RELEASE} -n ${IOMESH_NAMESPACE} &> /dev/null ; then
		error "IOMesh already installed. Use helm remove it first"
	fi
	info "Install IOMesh, It might take a long time..."
	helm install ${IOMESH_RELEASE} ${IOMESH_CHART} \
	  --atomic \
	  --debug \
	  --namespace ${IOMESH_NAMESPACE} \
	  --create-namespace \
	  --set chunk.dataCIDR="${IOMESH_DATA_CIDR}" \
	  --set meta.replicaCount="${META_REPLICAS}" \
	  --set zookeeper.replicas="${ZK_REPLICAS}" \
	  --set chunk.resources.requests.cpu="10m" \
	  --set chunk.resources.requests.memory="500Mi" \
	  --set meta.resources.requests.cpu="10m" \
	  --set meta.resources.requests.memory="100Mi" \
	  --timeout $TIME_OUT_SECOND \
	  --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a ${INSTALL_LOG_PATH}
	if [[ $? -ne 0 ]] ; then
		error "Fail to install IOMesh."
	fi

	#TODO(ziyin): check more resouces after install
	timeout=400 # 400s
	while true ; do
		if kubectl get pod ${IOMESH_RELEASE}-chunk-0 -n ${IOMESH_NAMESPACE} &> /dev/null ; then
			break
		fi

		sleep 5
		timeout=$(( timeout-5 ))
		if [[ $timeout -le 0 ]] ; then
			error "IOMesh resouces not all ready, use kubectl to check reason"
		fi
	done

	kubectl wait pod/${IOMESH_RELEASE}-chunk-0 --for condition=ready  -n ${IOMESH_NAMESPACE} --timeout=600s
	if [[ $? -ne 0 ]] ; then
		error "IOMesh resouces not all ready, use kubectl to check reason"
	fi
}

install_iomesh_csi() {
	# check if iomesh already installed
	if helm status ${IOMESH_CSI_RELEASE} -n ${IOMESH_CSI_NAMESPACE} &> /dev/null ; then
		error "IOMesh csi driver already installed. Use helm remove it first"
	fi

	info "Install IOMesh csi-driver, It might take a long time..."
	meta_proxy_addr=$(kubectl  get svc iomesh-access -n ${IOMESH_NAMESPACE} -o=jsonpath='{.spec.clusterIP}')
	if [[ ! "${meta_proxy_addr}" =~ [0-9]*\.[0-9]*\.[0-9]*\.[0-9]* ]] ; then
		error "Fail to get meta proxy addr for csi, IOMesh installed corrently?"
	fi

	helm install ${IOMESH_CSI_RELEASE} ${IOMESH_CSI_CHART} \
	  --atomic \
	  --debug \
	  --namespace ${IOMESH_CSI_NAMESPACE} \
	  --create-namespace \
	  --set driver.clusterID="${IOMESH_RELEASE}" \
	  --set driver.metaAddr="${meta_proxy_addr}":10206 \
	  --set driver.controller.replicas="${CSI_CONTROLLER_REPLICAS}" \
	  --set driver.node.mountIscsiLock="${MOUNT_ISCSI_LOCK}" \
	  --timeout $TIME_OUT_SECOND \
	  --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a ${INSTALL_LOG_PATH}
	if [[ $? -ne 0 ]] ; then
		error "Fail to install IOMesh csi."
	fi
}

init_helm_repo() {
	helm repo add iomesh http://iomesh.com/charts &> /dev/null
	info "Start update helm repo"
	if ! helm repo update 2> /dev/null ; then
		error "Helm update repo error."
	fi
}

init_log() {
	INSTALL_LOG_PATH=/tmp/iomesh_install-$(date +'%Y-%m-%d_%H-%M-%S').log
	if ! touch ${INSTALL_LOG_PATH} ; then
		error "Create log file ${INSTALL_LOG_PATH} error"
		return
	fi
	info "Log file create in path ${INSTALL_LOG_PATH}"
}

############################################
# Check if helm release deployment correctly
# Arguments:
#   release
#   namespace
############################################
release_deployed_correctly() {
	helm status "${1}" -n "${2}" | grep deployed &> /dev/null
	if [[ $? -ne 0 ]] ; then
		error "${1} installed fail, check log use helm and kubectl."
	fi
}

verify_installed() {
	release_deployed_correctly "${IOMESH_OPERATOR_RELEASE}" "${IOMESH_OPERATOR_NAMESPACE}"
	release_deployed_correctly "${IOMESH_RELEASE}" "${IOMESH_NAMESPACE}"
	release_deployed_correctly "${IOMESH_CSI_RELEASE}" "${IOMESH_CSI_NAMESPACE}"
	info "IOMesh Deployment Completed!"
	print_ascii_logo
}

print_ascii_logo() {
	echo "                                 "
	echo " ___ ___  __  __           _     "
	echo "|_ _/ _ \|  \/  | ___  ___| |__  "
	echo " | | | | | |\/| |/ _ \/ __| '_ \ "
	echo " | | |_| | |  | |  __/\__ \ | | |"
	echo "|___\___/|_|  |_|\___||___/_| |_|"
	echo "                                 "
}

main() {
	init_log
	verify_supported
	init_helm_repo
	install_snapshot_controller
	install_iomesh_operator
	install_iomesh
	install_iomesh_csi
	verify_installed
}

main

