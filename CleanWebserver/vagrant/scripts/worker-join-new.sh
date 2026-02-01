#!/bin/bash
# ============================================
# Worker Node Join
# Runs on fk-worker1 and fk-worker2
# ============================================

set -e

echo "========================================="
echo "Joining worker node to cluster..."
echo "========================================="

# Wait for join command to be available
while [ ! -f /vagrant/join-command.sh ]; do
  echo "Waiting for join command..."
  sleep 5
done

# Get join command from control plane
source /vagrant/join-command.sh

# Join cluster
sudo bash -c "$(cat /vagrant/join-command.sh)" -- --cri-socket=unix:///var/run/dockershim.sock

echo "✓ Worker node joined cluster successfully"
