# -*- mode: ruby -*-
# vi: set ft=ruby :

# FK Webstack - Kubeadm Cluster with Vagrant
# 1 Control Plane + 2 Worker Nodes
# Run: vagrant up

Vagrant.configure("2") do |config|
  # Base box
  config.vm.box = "ubuntu/jammy64"
  config.vm.boot_timeout = 600  # 10 minutes for slow systems
  
  # Shared settings
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048
    vb.cpus = 2
  end

  # Control Plane Node
  config.vm.define "fk-control" do |cp|
    cp.vm.hostname = "fk-control"
    cp.vm.network "private_network", ip: "192.168.56.10"
    
    cp.vm.provider "virtualbox" do |vb|
      vb.name = "fk-control"
      vb.memory = 6144
      vb.cpus = 4
    end

    cp.vm.provision "shell", path: "vagrant/01-base-setup.sh"
    cp.vm.provision "shell", path: "vagrant/02-kubeadm-install.sh"
    cp.vm.provision "shell", path: "vagrant/03-control-plane-init.sh"
  end

  # Worker Node 1
  config.vm.define "fk-worker1" do |w1|
    w1.vm.hostname = "fk-worker1"
    w1.vm.network "private_network", ip: "192.168.56.11"
    
    w1.vm.provider "virtualbox" do |vb|
      vb.name = "fk-worker1"
      vb.memory = 3072
      vb.cpus = 2
    end

    w1.vm.provision "shell", path: "vagrant/01-base-setup.sh"
    w1.vm.provision "shell", path: "vagrant/02-kubeadm-install.sh"
    w1.vm.provision "shell", path: "vagrant/04-worker-join.sh"
  end

  # Worker Node 2
  config.vm.define "fk-worker2" do |w2|
    w2.vm.hostname = "fk-worker2"
    w2.vm.network "private_network", ip: "192.168.56.12"
    
    w2.vm.provider "virtualbox" do |vb|
      vb.name = "fk-worker2"
      vb.memory = 3072
      vb.cpus = 2
    end

    w2.vm.provision "shell", path: "vagrant/01-base-setup.sh"
    w2.vm.provision "shell", path: "vagrant/02-kubeadm-install.sh"
    w2.vm.provision "shell", path: "vagrant/04-worker-join.sh"
  end
end
