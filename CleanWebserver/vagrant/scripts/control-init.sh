#!/bin/bash
# ============================================
# Control Plane Initialization
# Runs ONLY on fk-control
# ============================================

set -e

echo "========================================="
echo "Initializing Kubernetes Control Plane..."
echo "========================================="

# Initialize control plane
sudo kubeadm init \
  --apiserver-advertise-address=192.168.56.10 \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///var/run/dockershim.sock

# Setup kubeconfig for vagrant user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Flannel CNI
sleep 10
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# Wait for control plane to be ready
echo "Waiting for control plane to be ready..."
sleep 30

# Generate join token and save it
sudo kubeadm token create --print-join-command > /tmp/join-command.sh
cat /tmp/join-command.sh

# Copy to shared folder
sudo cp /tmp/join-command.sh /vagrant/join-command.sh
sudo chmod 644 /vagrant/join-command.sh

echo "✓ Control plane initialized successfully"
echo "✓ Join command saved to /vagrant/join-command.sh"
