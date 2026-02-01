#!/bin/bash
# FK Webstack - Control Plane Initialization
# Runs ONLY on fk-control
# Initializes the Kubernetes cluster

set -e

echo "=========================================="
echo "[3/3] Control Plane - Initializing Cluster"
echo "=========================================="

# Initialize cluster
echo "Running kubeadm init..."
kubeadm init \
  --apiserver-advertise-address=192.168.56.10 \
  --pod-network-cidr=10.244.0.0/16 \
  --kubernetes-version=v1.35.0

# Setup kubeconfig for root user
echo "Setting up kubeconfig..."
mkdir -p ~/.kube
cp /etc/kubernetes/admin.conf ~/.kube/config
chown root:root ~/.kube/config

# Install Flannel CNI (networking)
echo "Installing Flannel CNI..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready node --all --timeout=60s || true

# Generate and save join command for workers
echo "Generating join command for workers..."
JOIN_CMD=$(kubeadm token create --print-join-command)
echo "$JOIN_CMD" > /tmp/join-command.sh
chmod +x /tmp/join-command.sh

# Copy to shared folder so workers can access
cp /tmp/join-command.sh /vagrant/kubeadm-config/join-command.sh || true

echo "✓ Control plane initialized"
echo "  Cluster API: https://192.168.56.10:6443"
echo "  Nodes: $(kubectl get nodes --no-headers | wc -l) (more will join)"
echo "  Pods: $(kubectl get pods -A --no-headers | wc -l)"
echo ""
echo "Next: Workers will join cluster automatically"
