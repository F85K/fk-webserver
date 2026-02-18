#!/bin/bash
set -e

echo "======================================"
echo "Complete Worker Node Fix"
echo "======================================"

echo "Step 1: Delete old Flannel config..."
sudo rm -rf /run/flannel/ /etc/cni/net.d/*flannel* 2>/dev/null || true

echo "Step 2: Restart containerd..."
sudo systemctl restart containerd
sleep 5

echo "Step 3: Restart kubelet..."
sudo systemctl restart kubelet
sleep 10

echo "Step 4: Check status..."
systemctl status kubelet --no-pager | head -10

echo ""
echo "✅ Worker node services restarted"
