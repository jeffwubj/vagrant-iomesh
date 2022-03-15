#!/usr/bin/env bash

# bridged traffic to iptables is enabled for kube-router.
set -ex
echo "start to install..."
cat >> /etc/ufw/sysctl.conf <<EOF
net/bridge/bridge-nf-call-ip6tables = 1
net/bridge/bridge-nf-call-iptables = 1
net/bridge/bridge-nf-call-arptables = 1
EOF
IFNAME=$1
ADDRESS="$(ip -4 addr show $IFNAME | grep "inet" | head -1 |awk '{print $2}' | cut -d/ -f1)"
sed -e "s/^.*${HOSTNAME}.*/${ADDRESS} ${HOSTNAME} ${HOSTNAME}.local/" -i /etc/hosts
# remove ubuntu-bionic entry
sed -e '/^.*ubuntu-bionic.*/d' -i /etc/hosts
# Patch OS
apt-get update && apt-get upgrade -y
# Create local host entries
echo "10.0.0.10 master" >> /etc/hosts
echo "10.0.0.11 node1" >> /etc/hosts
echo "10.0.0.12 node2" >> /etc/hosts
echo "10.0.0.13 node3" >> /etc/hosts
# disable swap
swapoff -a
sed -i '/swap/d' /etc/fstab
# Install kubeadm, kubectl and kubelet
export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qq install ebtables ethtool
sudo apt-get -qq update
sudo apt-get -qq install -y docker.io apt-transport-https curl
# sudo setenforce 0
# sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# iscsi
sudo apt-get install open-iscsi -y
sudo sed -i 's/^node.startup = automatic$/node.startup = manual/' /etc/iscsi/iscsid.conf
sudo systemctl enable --now iscsid

sudo bash -c "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -"
sudo bash -c "cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF"
sudo apt-get -qq update
sudo  apt-get -qq install -y kubelet=1.21.0-00 kubeadm=1.21.0-00 kubectl=1.21.0-00
sudo  apt-mark hold kubelet kubectl kubeadm
# Set external DNS
sudo sed -i -e 's/#DNS=/DNS=8.8.8.8/' /etc/systemd/resolved.conf
sudo service systemd-resolved restart
sudo modprobe iscsi_tcp
sudo bash -c "echo iscsi_tcp > /etc/modules-load.d/iscsi_tcp.conf"