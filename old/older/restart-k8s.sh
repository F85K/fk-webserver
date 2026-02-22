#!/bin/bash
set -e

echo "======================================"
echo "Restarting Kubernetes API Server"
echo "======================================"

# Check kubelet status
echo "Checking kubelet..."
sudo systemctl status kubelet | head -15

echo ""
echo "Restarting kubelet..."
sudo systemctl restart kubelet

echo ""
echo "Waiting for API server to start..."
sleep 30

# Wait for API server
attempts=0
while ! kubectl get nodes 2>/dev/null && [ $attempts -lt 30 ]; do
    echo "Waiting for API server... (attempt $attempts)"
    sleep 5
    attempts=$((attempts+1))
done

echo ""
echo "API server status:"
kubectl get nodes

echo ""
echo "✅ Kubernetes is ready!"
