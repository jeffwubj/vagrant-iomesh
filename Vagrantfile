Vagrant.configure("2") do |config|
    config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
    config.vm.provision :shell, privileged: true, path: "install.sh"
  
    config.vm.define :master do |master|
      master.vm.provider :virtualbox do |vb|
        vb.name = "master"
        vb.memory = 4096
        vb.cpus = 2
      end
      master.vm.box = "ubuntu/bionic64"
      master.disksize.size = "50GB"
      master.vm.hostname = "master"
      master.vm.network :private_network, ip: "10.0.0.10"
      master.vm.provision :shell, privileged: false, path: "provision_master.sh"
    end
  
    %w{node1 node2 node3}.each_with_index do |name, i|
      config.vm.define name do |node|
        node.vm.provider "virtualbox" do |vb|
          vb.name = "node#{i + 1}"
          vb.memory = 4096
          vb.cpus = 2
        end
        node.vm.box = "ubuntu/bionic64"
        node.disksize.size = "50GB"
        node.vm.hostname = name
        node.vm.network :private_network, ip: "10.0.0.#{i + 11}"
        node.vm.provision :shell, privileged: false, inline: <<-SHELL
  sudo /vagrant/join.sh
  echo 'Environment="KUBELET_EXTRA_ARGS=--node-ip=10.0.0.#{i + 11}"' | sudo tee -a /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
  cat /vagrant/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
  sudo systemctl daemon-reload
  sudo systemctl restart kubelet
  SHELL
      end
    end
  
    config.vm.provision "shell", inline: $install_multicast
  end
  
  $install_multicast = <<-SHELL
  apt-get -qq install -y avahi-daemon libnss-mdns
  SHELL