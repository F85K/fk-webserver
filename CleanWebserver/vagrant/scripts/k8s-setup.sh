#!/bin/bash
# ============================================
# Complete Kubernetes Setup for kubeadm Cluster
# Runs on all nodes
# ============================================

set -e

echo "========================================="
echo "Installing Kubernetes tools..."
echo "========================================="

# Update system
sudo apt-get update
sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gpg \
  docker.io

# Add user to docker group
sudo usermod -aG docker vagrant

# Enable docker
sudo systemctl enable docker
sudo systemctl start docker

# Add Kubernetes repository
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install kubeadm, kubelet, kubectl
sudo apt-get update
sudo apt-get install -y kubeadm kubelet kubectl

# Enable kubelet
sudo systemctl enable kubelet

# Disable swap
sudo swapoff -a

echo "✓ Kubernetes tools installed successfully"
