#!/bin/bash
# Quick Puppet Certificate Signing Helper
# Run this on the control plane to sign all pending agent certificates

set -e

PUPPETSERVER_BIN="/opt/puppetlabs/server/bin/puppetserver"

echo "=========================================="
echo "Puppet Certificate Signing Script"
echo "=========================================="
echo ""

# Ensure puppet hostname is in /etc/hosts
if ! grep -q "127.0.0.1 puppet" /etc/hosts; then
    echo "Adding puppet hostname to /etc/hosts..."
    echo "127.0.0.1 puppet" | sudo tee -a /etc/hosts > /dev/null
fi

# Ensure puppetserver is running
echo "Ensuring Puppet Server is running..."
sudo systemctl is-active puppetserver || sudo systemctl start puppetserver
sleep 20

# List pending certificates
echo ""
echo "=== PENDING CERTIFICATES ==="
sudo $PUPPETSERVER_BIN ca list || echo "(Waiting for CA to initialize...)"

sleep 5

# Sign all pending certificates
echo ""
echo "=== SIGNING ALL CERTIFICATES ==="
sudo $PUPPETSERVER_BIN ca sign --all || echo "(No pending certificates to sign)"

sleep 5

# Show all signed certificates
echo ""
echo "=== ALL CERTIFICATES ==="
sudo $PUPPETSERVER_BIN ca list --all

echo ""
echo "=========================================="
echo "Certificate signing complete!"
echo "=========================================="
echo ""
echo "Next: Restart agents on workers"
echo "  vagrant ssh fk-worker1 -- 'sudo systemctl restart puppet'"
echo "  vagrant ssh fk-worker2 -- 'sudo systemctl restart puppet'"
