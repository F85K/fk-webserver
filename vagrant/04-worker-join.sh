#!/bin/bash
# Join worker node to cluster

set -e

echo "=== [WORKER] Joining cluster ==="

# Check if already joined
if [ -f /etc/kubernetes/kubelet.conf ]; then
    echo "✓ Already joined to cluster"
    exit 0
fi

# Wait for join command to be available (created by control plane)
MAX_WAIT=300
ELAPSED=0
while [ ! -f /vagrant/kubeadm-config/join-command.sh ] && [ $ELAPSED -lt $MAX_WAIT ]; do
    echo "Waiting for join command from control plane..."
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ ! -f /vagrant/kubeadm-config/join-command.sh ]; then
    echo "ERROR: Join command not found after 5 minutes"
    exit 1
fi

# Execute join command
echo "Executing join command..."
bash /vagrant/kubeadm-config/join-command.sh

# Setup kubeconfig for vagrant user
mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/kubelet.conf /home/vagrant/.kube/config
sed -i 's/system:node/system:node/' /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

echo "✓ Worker node joined cluster"
