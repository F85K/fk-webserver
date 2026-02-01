#!/bin/bash
# FK Webstack - Worker Node Join
# Runs ONLY on fk-worker1 and fk-worker2
# Joins workers to the cluster

set -e

echo "=========================================="
echo "[3/3] Worker - Joining Cluster"
echo "=========================================="

# Wait for join command to be available
echo "Waiting for join command from control plane..."
for i in {1..30}; do
    if [ -f /vagrant/kubeadm-config/join-command.sh ]; then
        echo "✓ Join command found"
        break
    fi
    echo "  Waiting... ($i/30)"
    sleep 2
done

# Get join command
if [ -f /vagrant/kubeadm-config/join-command.sh ]; then
    JOIN_CMD=$(cat /vagrant/kubeadm-config/join-command.sh)
    echo "Executing join command: $JOIN_CMD"
    
    # Join cluster
    eval $JOIN_CMD
    
    echo "✓ Worker node joined cluster"
else
    echo "✗ Join command not found!"
    exit 1
fi

echo "Worker provisioning complete"
echo "Node will appear in cluster momentarily"
