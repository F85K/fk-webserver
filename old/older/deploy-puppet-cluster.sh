#!/bin/bash
set -e

echo "=========================================="
echo "=== PUPPET CLUSTER DEPLOYMENT ==="
echo "=========================================="
echo ""

# Step 1: Install Puppet Server on control plane
echo "Step 1: Installing Puppet Server on fk-control..."
vagrant ssh fk-control -- "bash /vagrant/install-puppet-server.sh"

echo ""
echo "Step 2: Waiting 30 seconds for server to stabilize..."
sleep 30

# Step 2: Install Puppet Agents on workers
echo ""
echo "Step 3: Installing Puppet Agent on fk-worker1..."
vagrant ssh fk-worker1 -- "bash /vagrant/install-puppet-agent.sh"

echo ""
echo "Step 4: Installing Puppet Agent on fk-worker2..."
vagrant ssh fk-worker2 -- "bash /vagrant/install-puppet-agent.sh"

# Step 3: Sign certificates
echo ""
echo "Step 5: Approving agent certificates on control plane..."
sleep 5
vagrant ssh fk-control -- "sudo puppet cert sign --all"

echo ""
echo "Step 6: Restarting agents after certificate approval..."
vagrant ssh fk-worker1 -- "sudo systemctl restart puppet"
vagrant ssh fk-worker2 -- "sudo systemctl restart puppet"

sleep 10

# Step 4: Verify installation
echo ""
echo "=========================================="
echo "=== PUPPET INSTALLATION COMPLETE ==="
echo "=========================================="
echo ""

echo "Puppet Server Status:"
vagrant ssh fk-control -- "sudo systemctl status puppetserver --no-pager | head -5"

echo ""
echo "Agent Status on fk-worker1:"
vagrant ssh fk-worker1 -- "sudo systemctl status puppet --no-pager | head -5"

echo ""
echo "Agent Status on fk-worker2:"
vagrant ssh fk-worker2 -- "sudo systemctl status puppet --no-pager | head -5"

echo ""
echo "=========================================="
echo "=== NEXT STEPS ==="
echo "=========================================="
echo ""
echo "1. View agent status:"
echo "   vagrant ssh fk-control -- 'sudo puppet cert list'"
echo ""
echo "2. Test agent run:"
echo "   vagrant ssh fk-worker1 -- 'sudo puppet agent --test'"
echo ""
echo "3. View Puppet config:"
echo "   vagrant ssh fk-worker1 -- 'sudo /opt/puppetlabs/bin/puppet config print server'"
echo ""
echo "4. Apply manifests:"
echo "   vagrant ssh fk-control -- 'sudo puppet apply /vagrant/puppet/manifests/init.pp'"
echo ""
