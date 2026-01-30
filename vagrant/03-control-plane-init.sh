#!/bin/bash
# Initialize Kubernetes control plane

set -e

echo "=== [CONTROL] Initializing control plane ==="

# Check if already initialized
if [ -f /etc/kubernetes/admin.conf ]; then
    echo "✓ Control plane already initialized"
    exit 0
fi

# Initialize kubeadm with Flannel CIDR (simpler than Calico)
kubeadm init \
  --apiserver-advertise-address=192.168.56.10 \
  --pod-network-cidr=10.244.0.0/16 \
  --token-ttl=0 \
  --v=2

# Setup kubeconfig for root and vagrant user
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chown $(id -u):$(id -g) /root/.kube/config

mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

# Save join command for workers
kubeadm token create --print-join-command > /vagrant/kubeadm-config/join-command.sh
chmod +x /vagrant/kubeadm-config/join-command.sh

# Wait for control plane to be stable
echo "Waiting for API server to be stable (30 seconds)..."
sleep 30

# Verify API is responding
echo "Checking API server..."
max_attempts=10
attempts=0
while ! kubectl cluster-info &>/dev/null && [ $attempts -lt $max_attempts ]; do
    echo "  Waiting for API server... ($((attempts+1))/$max_attempts)"
    sleep 5
    attempts=$((attempts+1))
done

# Install Flannel CNI
echo "Installing Flannel CNI..."
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

echo "✓ Control plane initialized"
echo "✓ Kubeadm join command saved to /vagrant/kubeadm-config/join-command.sh"
