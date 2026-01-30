#!/bin/bash
# Install kubeadm, kubelet, kubectl

set -e

echo "=== [KUBEADM] Installing kubeadm, kubelet, kubectl ==="

# Add Kubernetes GPG key (using new key)
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repo (updated endpoint)
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install kubeadm components
apt-get update
apt-get install -y kubeadm=1.35.0-1.1 kubelet=1.35.0-1.1 kubectl=1.35.0-1.1
apt-mark hold kubeadm kubelet kubectl

# Enable kubelet
systemctl enable kubelet

echo "✓ Kubeadm tools installed (v1.35.0)"
