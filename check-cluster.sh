#!/bin/bash
set -e

echo "======================================"
echo "Cluster Recovery Script"
echo "======================================"

# Check if API server is responsive
echo "Checking API server..."
if kubectl get nodes 2>/dev/null; then
    echo "✅ API server is responsive"
else
    echo "❌ API server is down, restarting kubelet..."
    sudo systemctl restart kubelet
    sleep 10
fi

# Verify all nodes are ready
echo ""
echo "Node status:"
kubectl get nodes

# Check core pods
echo ""
echo "Core application pods:"
kubectl get pods -n fk-webstack

echo ""
echo "✅ Cluster recovery check complete"
