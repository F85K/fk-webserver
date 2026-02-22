# Kubernetes Control Plane Configuration with Puppet
# This provides Infrastructure as Code for kubernetes cluster

class k8s::base {
  # Ensure apt cache is updated
  exec { 'apt_update':
    command => '/usr/bin/apt-get update',
    unless  => '/bin/test -f /var/lib/apt/periodic/update-success-stamp && /usr/bin/find /var/lib/apt/periodic/update-success-stamp -mtime -1',
  }

  # Install essential packages
  package { ['curl', 'wget', 'git', 'vim', 'net-tools', 'jq', 'htop', 'python3-pip']:
    ensure   => 'present',
    require  => Exec['apt_update'],
  }

  # Configure sysctl for Kubernetes
  sysctl { 'net.ipv4.ip_forward':
    value => '1',
  }

  sysctl { 'net.bridge.bridge-nf-call-iptables':
    value => '1',
  }

  sysctl { 'net.bridge.bridge-nf-call-ip6tables':
    value => '1',
  }
}

class k8s::containerd_runtime {
  #  Install containerd
  package { 'containerd.io':
    ensure => 'present',
  }

  service { 'containerd':
    ensure  => 'running',
    enable  => true,
    require => Package['containerd.io'],
  }

  # Create containerd configuration directory
  file { '/etc/containerd':
    ensure => 'directory',
  }

  # Generate default containerd config
  exec { 'containerd_config':
    command => '/usr/bin/containerd config default > /etc/containerd/config.toml',
    creates => '/etc/containerd/config.toml',
    notify  => Service['containerd'],
    require => [Package['containerd.io'], File['/etc/containerd']],
  }
}

class k8s::control_plane {
  include k8s::base
  include k8s::containerd_runtime

  # Install k8s control plane tools
  package { ['kubeadm', 'kubelet', 'kubectl']:
    ensure => 'present',
  }

  # Ensure kubelet service is running
  service { 'kubelet':
    ensure  => 'running',
    enable  => true,
    require => [Package['kubelet'], Class['k8s::containerd_runtime']],
  }

  # Create kube config directories
  file { '/root/.kube':
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
  }

  # Logging for kubeadm init
  exec { 'kubeadm_init_check':
    command => '/usr/bin/kubectl get nodes',
    unless  => '/usr/bin/test -f /etc/kubernetes/manifests/kube-apiserver.yaml',
  }
}

class k8s::worker {
  include k8s::base
  include k8s::containerd_runtime

  # Install kubelet only (not kubectl or kubeadm)
  package { 'kubelet':
    ensure => 'present',
  }

  service { 'kubelet':
    ensure  => 'running',
    enable  => true',
    require => [Package['kubelet'], Class['k8s::containerd_runtime']],
  }
}

class k8s::networking {
  # Ensure network interfaces are configured
  exec { 'enable_ip_forward':
    command => '/sbin/sysctl -w net.ipv4.ip_forward=1',
    unless  => '/sbin/sysctl net.ipv4.ip_forward | grep -q "= 1"',
  }

  # Apply netplan config
  file { '/etc/netplan/99-k8s.yaml':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => 'puppet:///modules/k8s/netplan.yaml',
    notify  => Exec['netplan_apply'],
  }

  exec { 'netplan_apply':
    command     => '/usr/sbin/netplan apply',
    refreshonly => true,
  }
}

class k8s::monitoring {
  # Install basic monitoring tools
  package { ['prometheus-node-exporter']:
    ensure => 'present',
  }

  service { 'prometheus-node-exporter':
    ensure => 'running',
    enable => true,
  }
}
