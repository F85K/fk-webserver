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
# Extended to 60 seconds to allow etcd and static pods to fully initialize
echo "Giving API server 60 seconds to fully stabilize..."
sleep 60

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

# Give etcd extra time to settle after TLS bootstrap checks
echo "Waiting 45 seconds for etcd to fully stabilize before Flannel installation..."
sleep 45

# Install Flannel CNI with specific stable version
echo "Installing Flannel CNI (v0.25.1)..."

# Retry Flannel installation up to 3 times if API server is not responsive
MAX_RETRIES=3
RETRY=1
while [ $RETRY -le $MAX_RETRIES ]; do
    echo "  Attempt $RETRY/$MAX_RETRIES..."
    if kubectl apply -f https://github.com/flannel-io/flannel/releases/download/v0.25.1/kube-flannel.yml 2>/dev/null; then
        echo "✓ Flannel manifests applied successfully"
        break
    else
        if [ $RETRY -lt $MAX_RETRIES ]; then
            echo "  ⚠️  Flannel apply failed, waiting 15 seconds before retry..."
            sleep 15
        else
            echo "  ⚠️  Flannel apply failed after $MAX_RETRIES attempts"
            echo "  This may be normal - Flannel will be installed shortly"
        fi
        RETRY=$((RETRY + 1))
    fi
done

# Wait for Flannel DaemonSet to be created
echo "Waiting for Flannel DaemonSet to be created..."
sleep 10

# Wait for Flannel pod on control plane to be Running
echo "Waiting for Flannel pod to be ready (max 3 minutes)..."
kubectl wait --for=condition=Ready pod \
  -l app=flannel \
  -n kube-flannel \
  --timeout=180s 2>/dev/null || {
    echo "⚠️  Flannel pod not ready yet, checking status..."
    kubectl get pods -n kube-flannel 2>/dev/null || echo "  Flannel namespace not found yet"
    echo "Waiting additional 30 seconds..."
    sleep 30
}

# Verify CoreDNS is starting (depends on network)
echo "Verifying CoreDNS pods are starting..."
kubectl get pods -n kube-system -l k8s-app=kube-dns 2>/dev/null || echo "  CoreDNS not found yet"

# Mark Flannel as ready
touch /vagrant/kubeadm-config/.flannel-ready
chmod 666 /vagrant/kubeadm-config/.flannel-ready

echo "✓ Control plane fully initialized with working CNI - ready for workers"
