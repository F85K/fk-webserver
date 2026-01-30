#!/bin/bash
# Base setup for all nodes: Docker, iptables, swap disable

set -e

echo "=== [BASE] Installing prerequisites ==="

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
echo "Installing Docker..."
apt-get install -y docker.io
usermod -aG docker vagrant
systemctl enable docker
systemctl start docker

# Configure iptables for Kubernetes
echo "Configuring iptables..."
modprobe overlay
modprobe br_netfilter

cat >> /etc/sysctl.d/99-kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# Disable swap (required for kubeadm)
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Set up shared config directory for kubeadm join command
mkdir -p /vagrant/kubeadm-config
chmod 777 /vagrant/kubeadm-config

echo "✓ Base setup complete"
