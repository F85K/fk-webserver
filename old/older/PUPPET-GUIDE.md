# Puppet Integration for Kubernetes Cluster Management
# Infrastructure as Code approach for cluster configuration

## Overview
This demonstrates how Puppet can be used to manage the Kubernetes cluster infrastructure as code, ensuring consistent configuration across all nodes.

## Puppet Benefits for K8s:
1. **Configuration Management**: Version control for all infrastructure settings
2. **Idempotent Operations**: Safe to run repeatedly
3. **Multi-node Coordination**: Manage control plane + workers consistently
4. **Enforcement**: Ensure desired state is maintained
5. **Auditability**: Clear history of infrastructure changes

## Installation

### On Master Node (fk-control):
```bash
# Install Puppet Server
sudo apt-get install -y puppet-server

# Start Puppet Server
sudo systemctl start puppetserver
sudo systemctl enable puppetserver

# Check status
sudo systemctl status puppetserver
```

### On Worker Nodes:
```bash
# Install Puppet Agent
sudo apt-get install -y puppet-agent

# Configure puppet agent
sudo puppet config set server fk-control --section agent
sudo puppet config set ca_server fk-control --section agent

# Start Puppet Agent
sudo systemctl start puppet
sudo systemctl enable puppet

# Sign certificates on master
sudo puppet cert list    # See pending requests
sudo puppet cert sign --all  # Sign all requests
```

## Puppet Manifests Structure

```
puppet/
├── manifests/
│   ├── init.pp              # Main kubernetes classes
│   ├── control_plane.pp     # Control plane specific configs
│   └── worker.pp            # Worker node specific configs
├── modules/
│   └── k8s/
│       ├── files/
│       │   └── netplan.yaml # Network configuration
│       ├── templates/
│       └── manifests/       # Resource definitions
├── hiera.yaml               # Configuration data
└── k8s-cluster.json         # Cluster definition
```

## Usage

### Deploy Configuration to All Nodes:
```bash
# On control plane - apply manifests
sudo puppet apply puppet/manifests/init.pp \
  -e "include k8s::control_plane"

# On worker nodes - apply node configuration
sudo puppet apply puppet/manifests/init.pp \
  -e "include k8s::worker"
```

### Check Configuration Status:
```bash
# List managed resources
sudo puppet resource package

# Check specific service status
sudo puppet resource service kubelet

# Dry-run (no changes)
sudo puppet apply puppet/manifests/init.pp --noop
```

### Key Resources Managed by Puppet:

1. **Packages**: containerd, kubelet, kubeadm, kubectl
2. **Services**: kubelet, containerd, Docker
3. **Files**: Network configs, kubernetes configs,  kubeadm configs
4. **Exec resources**: kubeadm init, kubeadm join, kubectl commands
5. **Sysctl settings**: Kernel parameters for networking

### Real-World Workflow:

```bash
# 1. Update manifest based on requirements
vi puppet/manifests/init.pp

# 2. Test on a single node (dry-run)
sudo puppet apply puppet/manifests/init.pp --noop --debug

# 3. Apply to control plane
sudo puppet apply puppet/manifests/init.pp

# 4. Apply to workers via agent (if using Puppet Server)
# Or manually:
vagrant ssh fk-worker1 -- "sudo puppet apply /vagrant/puppet/manifests/init.pp"
vagrant ssh fk-worker2 -- "sudo puppet apply /vagrant/puppet/manifests/init.pp"

# 5. Verify cluster status
sudo kubectl get nodes
```

## Integration with Vagrant

Add to Vagrantfile:
```ruby
config.vm.provision "puppet" do |puppet|
  puppet.manifests_path = "puppet/manifests"
  puppet.manifest_file = "init.pp"
  puppet.module_path = "puppet/modules"
  puppet.hiera_config_path = "puppet/hiera.yaml"
  puppet.options = "--verbose --debug"
end
```

## Monitoring with Puppet

The k8s::monitoring class deploys:
- prometheus-node-exporter: 9100 (hardware metrics)
- Puppet dashboard: Central monitoring of all nodes

```bash
# View exported facts/resources
sudo puppet facts
```

## Benefits Demonstrated

1. **Infrastructure as Code**: All cluster setup in version-controlled manifests
2. **Consistency**: Same config applied across all nodes
3. **Repeatability**: Can destroy and rebuild cluster easily
4. **Documentation**: Manifests serve as documentation
5. **Declarative**: Describe desired state, not steps
6. **Compliance**: Easily audit and enforce standards

## Next Steps

1. Integrate with git for version control
2. Use Hiera for environment-specific config
3. Add custom resources for k8s-specific operations
4. Monitor infrastructure changes via Puppet reports
5. Implement continuous compliance checking
