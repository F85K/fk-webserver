#!/bin/bash
# Join worker node to cluster

set -e

echo "=== [WORKER] Joining cluster ==="

# Check if already joined
if [ -f /etc/kubernetes/kubelet.conf ]; then
    echo "✓ Already joined to cluster"
    exit 0
fi

# Wait for control plane to signal it's ready
echo "⏳ Waiting for control plane to be ready..."
MAX_WAIT=900  # 15 minutes for control plane to initialize
ELAPSED=0
READY_MARKER="/vagrant/kubeadm-config/.control-plane-ready"

while [ ! -f "$READY_MARKER" ] && [ $ELAPSED -lt $MAX_WAIT ]; do
    REMAINING=$((MAX_WAIT - ELAPSED))
    echo "   [$(date '+%H:%M:%S')] Waiting for control plane... ($REMAINING seconds remaining)"
    sleep 15
    ELAPSED=$((ELAPSED + 15))
done

if [ ! -f "$READY_MARKER" ]; then
    echo "⚠️  Control plane ready marker not found, but continuing anyway..."
    sleep 30
fi

# CRITICAL: Wait for Flannel/CNI to be ready on control plane
# Workers need CNI to be functional before joining
echo "⏳ Waiting for Flannel CNI to be ready on control plane..."
MAX_WAIT=600
ELAPSED=0
FLANNEL_MARKER="/vagrant/kubeadm-config/.flannel-ready"

while [ ! -f "$FLANNEL_MARKER" ] && [ $ELAPSED -lt $MAX_WAIT ]; do
    REMAINING=$((MAX_WAIT - ELAPSED))
    echo "   [$(date '+%H:%M:%S')] Waiting for CNI... ($REMAINING seconds remaining)"
    sleep 15
    ELAPSED=$((ELAPSED + 15))
done

if [ ! -f "$FLANNEL_MARKER" ]; then
    echo "⚠️  Flannel marker not found, but continuing anyway..."
    echo "   Note: Worker may need manual intervention if networking fails"
    sleep 20
fi

# Wait for join command to be available (created by control plane)
# This can take 2-5 minutes depending on control plane initialization
MAX_WAIT=600  # 10 minutes
ELAPSED=0
JOIN_CMD="/vagrant/kubeadm-config/join-command.sh"

echo "⏳ Waiting for join command from control plane (max 10 minutes)..."
while [ ! -f "$JOIN_CMD" ] && [ $ELAPSED -lt $MAX_WAIT ]; do
    REMAINING=$((MAX_WAIT - ELAPSED))
    echo "   [$(date '+%H:%M:%S')] Still waiting... ($REMAINING seconds remaining)"
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [ ! -f "$JOIN_CMD" ]; then
    echo "❌ ERROR: Join command not found after 10 minutes"
    echo "   This means the control plane did not complete initialization"
    echo "   Try manually: vagrant ssh fk-control -- kubectl get nodes"
    exit 1
fi

# Verify join command is not empty
if [ ! -s "$JOIN_CMD" ]; then
    echo "❌ ERROR: Join command file is empty"
    exit 1
fi

# Execute join command with retries
echo "✓ Join command found, executing..."
MAX_JOIN_RETRIES=3
JOIN_ATTEMPT=1
while [ $JOIN_ATTEMPT -le $MAX_JOIN_RETRIES ]; do
    echo "   Attempt $JOIN_ATTEMPT/$MAX_JOIN_RETRIES..."
    if bash "$JOIN_CMD"; then
        echo "✓ Join successful!"
        break
    else
        JOIN_ATTEMPT=$((JOIN_ATTEMPT + 1))
        if [ $JOIN_ATTEMPT -le $MAX_JOIN_RETRIES ]; then
            echo "   Join failed, cleaning up Kubernetes state before retry..."
            # Clean up kubeadm state for fresh retry
            sudo systemctl stop kubelet || true
            sudo rm -f /etc/kubernetes/kubelet.conf
            sudo rm -f /etc/kubernetes/pki/ca.crt
            sudo rm -rf /var/lib/kubelet/pki/*
            echo "   Waiting 10 seconds before retry..."
            sleep 10
            echo "   Restarting kubelet..."
            sudo systemctl start kubelet || true
            sleep 5
        fi
    fi
done

if [ $JOIN_ATTEMPT -gt $MAX_JOIN_RETRIES ]; then
    echo "❌ ERROR: Failed to join cluster after $MAX_JOIN_RETRIES attempts"
    exit 1
fi

# Setup kubeconfig for vagrant user
mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/kubelet.conf /home/vagrant/.kube/config
sed -i 's/system:node/system:node/' /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

# Post-join verification: Wait for Flannel pod on this worker
echo "⏳ Waiting for Flannel pod to start on this worker node (max 2 minutes)..."
sleep 20  # Give Flannel DaemonSet time to schedule pod

# Restart kubelet to ensure Flannel is properly picked up
echo "Restarting kubelet to ensure CNI is loaded..."
systemctl restart kubelet
sleep 10

echo "✓ Worker node joined cluster successfully"
echo "   Note: It may take 30-60 seconds for the node to become Ready"
