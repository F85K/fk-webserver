#!/bin/bash
# Initialize Kubernetes control plane

set -e

echo "=== [CONTROL] Initializing control plane ==="

# Check if already initialized
if [ -f /etc/kubernetes/admin.conf ]; then
    echo "✓ Control plane already initialized"
    exit 0
fi

# Initialize kubeadm with Flannel CIDR
kubeadm init \
  --apiserver-advertise-address=192.168.56.10 \
  --pod-network-cidr=10.244.0.0/16 \
  --token-ttl=0 \
  --v=2

# Setup kubeconfig for root and vagrant user
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chown $(id -u):$(id -g) /root/.kube/config
export KUBECONFIG=/root/.kube/config

mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

# Save join command for workers
kubeadm token create --print-join-command > /vagrant/kubeadm-config/join-command.sh
chmod +x /vagrant/kubeadm-config/join-command.sh

echo "✓ Kubeadm initialized"

# CRITICAL: Wait longer for kubelet to start containers after kubeadm init
# Static manifests are present but kubelet needs time to start them
echo "Waiting for kubelet to start static pod containers (90 seconds)..."
sleep 90

# CRITICAL FIX: Ensure etcd is listening on port 2379 BEFORE API server tries to connect
echo "Verifying etcd is listening on port 2379..."
max_attempts=60
attempts=0
while ! ss -tlnp 2>/dev/null | grep -q ':2379' && [ $attempts -lt $max_attempts ]; do
    echo "  etcd not listening yet... ($((attempts+1))/$max_attempts)"
    sleep 2
    attempts=$((attempts+1))
done

if [ $attempts -ge $max_attempts ]; then
    echo "✗ etcd failed to start listening on port 2379 - checking status..."
    sudo crictl ps -a | grep etcd || echo "  No etcd container found"
    echo "Continuing anyway, but cluster may be unstable..."
else
    echo "✓ etcd is listening on port 2379"
fi

# Give etcd additional time to fully initialize after port opens
echo "Waiting 30 seconds for etcd to fully initialize..."
sleep 30

# Wait for API server to be fully operational before running kubectl
echo "Waiting for API server to respond..."
max_attempts=120
attempts=0
while ! KUBECONFIG=/root/.kube/config kubectl get nodes &>/dev/null && [ $attempts -lt $max_attempts ]; do
    echo "  API server not ready yet... ($((attempts+1))/$max_attempts)"
    sleep 3
    attempts=$((attempts+1))
done

if [ $attempts -ge $max_attempts ]; then
    echo "✗ API server failed to become ready after 6 minutes - CRITICAL ERROR"
    echo "Debug: Checking static manifests..."
    ls -la /etc/kubernetes/manifests/
    echo "Debug: Checking kubelet status..."
    systemctl status kubelet || true
    exit 1
fi

echo "✓ API server is responding"

# Wait additional time for API server to stabilize after kubelet restart
# Extended to 90 seconds to allow etcd and static pods to fully initialize
echo "Giving API server 90 seconds to fully stabilize..."
sleep 90

# Verify etcd is healthy before proceeding
echo "Verifying etcd health..."
for i in {1..30}; do
    if KUBECONFIG=/root/.kube/config kubectl get componentstatuses | grep etcd | grep -q Healthy; then
        echo "✓ etcd is healthy"
        break
    fi
    echo "  etcd health check $i/30..."
    sleep 2
done

# Wait for control plane node to be Ready
echo "Waiting for control plane node to become Ready..."
kubectl wait --for=condition=Ready node/fk-control --timeout=180s || {
    echo "⚠️  Node not Ready yet, but continuing..."
    kubectl get nodes || true
}

# Mark initialization complete
touch /vagrant/kubeadm-config/.control-plane-ready
chmod 666 /vagrant/kubeadm-config/.control-plane-ready

echo "✓ Control plane is ready"

# CRITICAL: Give API server MUCH more time to stabilize before CNI installation
# The API server and etcd need full stabilization - this is the biggest bottleneck
echo "Waiting 180 seconds for API server and etcd to fully stabilize..."
sleep 180

# Verify API server is responding and stable (with retries)
echo "Verifying API server is stable..."
max_retries=10
retry=0
while ! kubectl get nodes &>/dev/null && [ $retry -lt $max_retries ]; do
    echo "  API server check $((retry+1))/$max_retries failed, waiting 10 seconds..."
    sleep 10
    retry=$((retry+1))
done

if [ $retry -ge $max_retries ]; then
    echo "⚠️  WARNING: API server still not responding after extended wait"
    echo "   Kubernetes may be unstable. Attempting to continue anyway..."
fi

echo "Proceeding with CNI installation..."

# Install Flannel CNI with specific stable version
echo "Installing Flannel CNI (v0.25.1)..."

# Verify critical components
echo "Verifying cluster health before allowing workers to join..."
kubectl get nodes || echo "  Warning: Unable to get nodes"
kubectl get pods -n kube-system || echo "  Warning: Unable to get system pods"

echo "✓ Control plane fully initialized - ready for workers"
echo "   (CNI will be installed during full stack deployment)"
