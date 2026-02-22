#!/bin/bash
# Base setup for all nodes: Docker, iptables, swap disable

set -e

echo "=== [BASE] Installing prerequisites ==="

# Update system
apt-get update
apt-get upgrade -y

# Install and configure containerd for Kubernetes
echo "Installing containerd..."

# Add Docker repository for containerd
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update and install containerd
apt-get update
apt-get install -y containerd.io

# Create default containerd config
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# Update config to use systemd cgroup driver (required by kubeadm)
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Enable and start containerd
systemctl enable containerd
systemctl restart containerd
systemctl start containerd

echo "✓ Containerd installed and configured"

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
