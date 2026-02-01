#!/bin/bash
# FK Webstack - Kubeadm Tools Installation
# Runs on ALL VMs (control + workers)
# Installs kubeadm, kubelet, kubectl

set -e

echo "=========================================="
echo "[2/3] Installing Kubeadm Tools v1.35.0"
echo "=========================================="

# Add Kubernetes APT repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update

# Install kubeadm, kubelet, kubectl
echo "Installing kubeadm, kubelet, kubectl..."
apt-get install -y --no-install-recommends \
    kubeadm=1.35.0-1.1 \
    kubelet=1.35.0-1.1 \
    kubectl=1.35.0-1.1 \
    cri-tools=1.35.0-1.1

# Hold packages to prevent accidental updates
apt-mark hold kubeadm kubelet kubectl

# Start kubelet (will enter crash loop until cluster initialized, that's OK)
systemctl enable kubelet
systemctl start kubelet || true

echo "✓ Kubeadm tools installed (v1.35.0)"
echo "  kubeadm version: $(kubeadm version -o short)"
echo "  kubelet version: $(kubelet --version)"
echo "  kubectl version: $(kubectl version --client --short 2>/dev/null || echo 'Not available yet')"
