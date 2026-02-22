#!/bin/bash
set -e

echo "=========================================="
echo "=== PUPPET AGENT INSTALLATION ==="
echo "=========================================="
echo ""

# Add Puppet repository
echo "[1] Adding Puppet repository..."
wget -q https://apt.puppet.com/puppet-release-jammy.deb
sudo dpkg -i puppet-release-jammy.deb
sudo apt-get update -qq

# Install Puppet Agent
echo "[2] Installing Puppet Agent..."
sudo apt-get install -y puppet-agent 2>&1 | tail -3

# Configure agent to connect to master
echo "[3] Configuring Puppet Agent for master: fk-control..."
sudo /opt/puppetlabs/bin/puppet config set server fk-control --section agent
sudo /opt/puppetlabs/bin/puppet config set ca_server fk-control --section agent

# Start Puppet Agent
echo "[4] Starting Puppet Agent..."
sudo systemctl enable puppet 2>/dev/null || true
sudo systemctl start puppet

echo ""
echo "[5] Waiting for agent to request certificate..."
sleep 10

echo ""
echo "=========================================="
echo "=== PUPPET AGENT READY ==="
echo "=========================================="
echo ""
echo "Agent: $(hostname)"
echo "Master: fk-control (192.168.56.10)"
echo ""
echo "Next on control plane: Approve certificate"
echo "  sudo puppet cert sign --all"
