# -*- mode: ruby -*-
# vi: set ft=ruby :

# FK Webstack - Kubeadm Cluster with Vagrant
# BARE VM CONFIGURATION ONLY (no auto-provisioning)
# 1 Control Plane + 2 Worker Nodes
# Total RAM: 12GB (6GB control + 3GB worker1 + 3GB worker2)
#
# Usage:
#   vagrant up                    # Create bare VMs only (5-10 min)
#   vagrant ssh fk-control       # SSH into control plane
#   # Then manually run provisioning scripts inside VMs

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_version = "20241002.0.0"
  config.vm.boot_timeout = 900  # 15 minutes for slow systems
  
  # SSH speed optimization
  config.ssh.connect_timeout = 15
  config.ssh.keep_alive = true
  config.ssh.compression = true
  
  # Disable default shared folder syncing (optional - set to true if needed)
  config.vm.synced_folder ".", "/vagrant", disabled: false

  # ===================================================
  # CONTROL PLANE NODE
  # ===================================================
  # 6GB RAM - Handles etcd, API server, scheduler, controller-manager
  # NO PROVISIONING - VMs boot clean for debugging
  config.vm.define "fk-control" do |control|
    control.vm.hostname = "fk-control"
    control.vm.network "private_network", ip: "192.168.56.10"
    
    control.vm.provider "virtualbox" do |vb|
      vb.name = "fk-control"
      vb.memory = 6144  # 6GB RAM
      vb.cpus = 4       # 4 CPUs
    end
  end

  # ===================================================
  # WORKER NODE 1
  # ===================================================
  # 3GB RAM - Handles application workloads
  config.vm.define "fk-worker1" do |worker1|
    worker1.vm.hostname = "fk-worker1"
    worker1.vm.network "private_network", ip: "192.168.56.11"
    
    worker1.vm.provider "virtualbox" do |vb|
      vb.name = "fk-worker1"
      vb.memory = 3072  # 3GB RAM
      vb.cpus = 2       # 2 CPUs
    end
  end

  # ===================================================
  # WORKER NODE 2
  # ===================================================
  # 3GB RAM - Handles application workloads
  config.vm.define "fk-worker2" do |worker2|
    worker2.vm.hostname = "fk-worker2"
    worker2.vm.network "private_network", ip: "192.168.56.12"
    
    worker2.vm.provider "virtualbox" do |vb|
      vb.name = "fk-worker2"
      vb.memory = 3072  # 3GB RAM
      vb.cpus = 2       # 2 CPUs
    end
  end
end
