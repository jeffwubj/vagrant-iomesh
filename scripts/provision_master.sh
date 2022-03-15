set -ex
OUTPUT_FILE=/vagrant/join.sh
KEY_FILE=/vagrant/id_rsa.pub
rm -rf $OUTPUT_FILE
rm -rf $KEY_FILE
# Create key
ssh-keygen -q -t rsa -b 4096 -N '' -f /home/vagrant/.ssh/id_rsa
cat /home/vagrant/.ssh/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
cat /home/vagrant/.ssh/id_rsa.pub > ${KEY_FILE}
# Start cluster
sudo kubeadm init --kubernetes-version=1.21.0 --apiserver-advertise-address=10.0.0.10 --pod-network-cidr=10.244.0.0/16 | grep -Ei "kubeadm join|discovery-token-ca-cert-hash" > ${OUTPUT_FILE}
chmod +x $OUTPUT_FILE
# Configure kubectl for vagrant and root users
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
sudo mkdir -p /root/.kube
sudo cp -i /etc/kubernetes/admin.conf /root/.kube/config
sudo chown -R root:root /root/.kube
# Fix kubelet IP
echo 'Environment="KUBELET_EXTRA_ARGS=--node-ip=10.0.0.10"' | sudo tee -a /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
# Use our flannel config file so that routing will work properly
kubectl create -f /vagrant/config/kube-flannel.yml
# Set alias on master for vagrant and root users
echo "alias k=/usr/bin/kubectl" >> $HOME/.bash_profile
# Install the etcd client
sudo apt install etcd-client
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo rm -rf /vagrant/kubeconfig
sudo cp -i $HOME/.kube/config /vagrant/kubeconfig