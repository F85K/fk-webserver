#!/bin/bash
# FK Webstack - Base Setup Script
# Runs on ALL VMs (control + workers)
# Installs Docker and configures networking
#
# This is run first by Vagrant before specific scripts

set -e  # Exit on error

echo "=========================================="
echo "[1/3] Base Setup - Docker & Networking"
echo "=========================================="

# Update package list
apt-get update
apt-get upgrade -y

# Install Docker
echo "Installing Docker 28.2.2..."
apt-get install -y --no-install-recommends \
    docker.io=5:28.2.2-0~ubuntu-jammy \
    containerd=1.7.28-0ubuntu1~22.04.1 \
    bridge-utils \
    iptables \
    curl \
    wget

# Start Docker daemon
systemctl enable docker
systemctl start docker
systemctl enable containerd

# Configure networking for Kubernetes
echo "Configuring networking..."
cat > /etc/sysctl.d/99-kubernetes.conf << EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl -p /etc/sysctl.d/99-kubernetes.conf

# Disable swap (required by Kubernetes)
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

echo "✓ Base setup complete"
echo "  Docker version: $(docker --version)"
echo "  Containerd version: $(containerd --version)"
