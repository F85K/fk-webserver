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
            echo "   Join failed, retrying in 10 seconds..."
            sleep 10
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

echo "✓ Worker node joined cluster"
