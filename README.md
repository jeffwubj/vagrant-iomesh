## vagrant-iomesh
a local cloud native storage playground powered by vagrant/virtualbox and [iomesh](https://github.com/iomesh).

## Dependencies

You should install [VirtualBox](https://www.virtualbox.org/wiki/Downloads) and [Vagrant](https://www.vagrantup.com/downloads.html) before you start.

Below enviroments have been verified:
- Host: CentOS-7 VM with 20G Memory and VT enabled
- VirtualBox: 6.0.24r139119
- Vagrant: 2.2.19

## Starting the cluster

```
vagrant up
cp ./kubeconfig $HOME/.kube
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
## Check Result

After a long wait, once succeed, it will print below message:

```
    node3: [Info][2022-03-15T13:42:28+0000]: IOMesh Deployment Completed!
    node3:
    node3:  ___ ___  __  __           _
    node3: |_ _/ _ \|  \/  | ___  ___| |__
    node3:  | | | | | |\/| |/ _ \/ __| '_ \
    node3:  | | |_| | |  | |  __/\__ \ | | |
    node3: |___\___/|_|  |_|\___||___/_| |_|
    node3:

```

## Thanks to...
[LocusInnovations](https://github.com/LocusInnovations/k8s-vagrant-virtualbox)
