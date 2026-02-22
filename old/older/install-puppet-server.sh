#!/bin/bash
set -e

echo "=========================================="
echo "=== PUPPET SERVER INSTALLATION ==="
echo "=========================================="
echo ""

# Add Puppet repository
echo "[1] Adding Puppet repository..."
wget -q https://apt.puppet.com/puppet-release-jammy.deb
sudo dpkg -i puppet-release-jammy.deb
sudo apt-get update -qq

# Install Puppet Server
echo "[2] Installing Puppet Server..."
sudo apt-get install -y puppetserver 2>&1 | tail -3

# Configure JVM memory
echo "[3] Configuring Puppet Server memory..."
sudo sed -i 's/-Xms2g/-Xms512m/g' /etc/default/puppetserver
sudo sed -i 's/-Xmx2g/-Xmx512m/g' /etc/default/puppetserver

# Start Puppet Server
echo "[4] Starting Puppet Server..."
sudo systemctl enable puppetserver 2>/dev/null || true
sudo systemctl start puppetserver

# Wait for server to boot
echo "[5] Waiting for Puppet Server to start (30s)..."
for i in {1..30}; do
    if sudo systemctl is-active --quiet puppetserver; then
        echo "  ✓ Puppet Server is running"
        break
    fi
    echo -n "."
    sleep 1
done

echo ""
echo "[6] Verifying Puppet Server..."
sudo puppet --version
sudo puppetserver --version 2>/dev/null || echo "  (Puppetserver CLI)"

echo ""
echo "=========================================="
echo "=== PUPPET SERVER READY ==="
echo "=========================================="
echo ""
echo "Server: fk-control (192.168.56.10)"
echo "Next: Install agents on workers"
