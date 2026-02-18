#!/bin/bash
set -e

echo "======================================"
echo "Fix Worker1 Networking"
echo "======================================"

echo "Restarting containerd and kubelet..."
sudo systemctl restart containerd
sleep 5
sudo systemctl restart kubelet
sleep 10

echo ""
echo "Worker node status:"
hostname
systemctl status kubelet | head -5

echo ""
echo "✅ Worker1 restart complete"
