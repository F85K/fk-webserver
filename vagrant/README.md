# FK Webstack - Kubeadm Cluster with Vagrant

This setup creates a **3-node Kubernetes cluster** using Vagrant and VirtualBox:
- **1 Control Plane Node** (fk-control): 192.168.56.10
- **2 Worker Nodes** (fk-worker1, fk-worker2): 192.168.56.11, 192.168.56.12

## Prerequisites

1. **Install Vagrant** (Windows): https://www.vagrantup.com/downloads
2. **Install VirtualBox** (Windows): https://www.virtualbox.org/wiki/Downloads
3. **Add to PATH** (Windows):
   - Vagrant: `C:\HashiCorp\Vagrant\bin`
   - VirtualBox: `C:\Program Files\Oracle\VirtualBox`

Verify:
```powershell
vagrant --version
vboxmanage --version
```

## Quick Start

### 1. Start the Cluster (15-20 minutes)
```powershell
cd C:\Users\Admin\Desktop\WebserverLinux
vagrant up
```

This will:
- Download Ubuntu 22.04 base image (~500MB)
- Create 3 VMs
- Install Docker on all nodes
- Install kubeadm, kubelet, kubectl (v1.35.0)
- Initialize control plane with Calico CNI
- Join worker nodes to cluster

### 2. Access Control Plane
```powershell
# SSH into control plane
vagrant ssh fk-control

# Inside VM:
kubectl get nodes
kubectl get pods -n calico-system
```

### 3. Setup kubeconfig on Host (Windows)
```powershell
# From Vagrant directory
mkdir $env:USERPROFILE\.kube
vagrant ssh fk-control -c "cat /etc/kubernetes/admin.conf" > $env:USERPROFILE\.kube\config

# Verify
kubectl get nodes
```

### 4. Build and Push Docker Images
```powershell
# From project root
docker build -t fk-api:latest ./api
docker build -t fk-frontend:latest ./frontend

# Push to docker hub or private registry
docker tag fk-api:latest yourrepo/fk-api:latest
docker push yourrepo/fk-api:latest
```

### 5. Deploy ArgoCD + FK Stack
```powershell
# SSH to control plane
vagrant ssh fk-control

# Inside VM, run deployment script
bash /vagrant/vagrant/05-deploy-argocd.sh
```

This will:
- Install Helm
- Install cert-manager
- Install ArgoCD via Helm Chart
- Deploy FK webstack manifests
- Setup ArgoCD Application for GitOps

### 6. Access Applications

**ArgoCD UI:**
```powershell
# Port-forward ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Open browser
https://localhost:8080
# User: admin
# Password: (from deployment script output)
```

**FK Application:**
```powershell
# Add to hosts file (requires Admin)
127.0.0.1 fk.local

# Port-forward frontend service
kubectl port-forward -n fk-webstack svc/fk-frontend 80:80

# Or if Ingress is working:
https://fk.local
```

## Troubleshooting

### VMs won't start
```powershell
# Check VirtualBox is installed
vboxmanage --version

# Enable virtualization in BIOS
# Restart computer and enter BIOS (F2, Del, etc.)
```

### Cluster nodes not joining
```powershell
# Check logs on worker
vagrant ssh fk-worker1
sudo journalctl -u kubelet -f

# Check on control plane
sudo kubeadm token create --print-join-command
```

### kubectl can't connect
```powershell
# Copy config from control plane
vagrant ssh fk-control -c "cat /etc/kubernetes/admin.conf" > $env:USERPROFILE\.kube\config

# Check API server is listening
kubectl cluster-info
```

### Delete and start fresh
```powershell
vagrant destroy -f
vagrant up
```

## Cluster Architecture

```
┌─────────────────────────────────────────────┐
│         Kubernetes Cluster (kubeadm)        │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │   fk-control (Control Plane)        │   │
│  │   192.168.56.10                     │   │
│  │                                     │   │
│  │  • API Server                       │   │
│  │  • etcd                             │   │
│  │  • Scheduler                        │   │
│  │  • Controller Manager               │   │
│  │  • Calico CNI                       │   │
│  └─────────────────────────────────────┘   │
│           │                                 │
│     ┌─────┴─────┐                          │
│     │           │                          │
│  ┌──────────┐  ┌──────────┐               │
│  │fk-worker1│  │fk-worker2│               │
│  │192.168.. │  │192.168.. │               │
│  │          │  │          │               │
│  │• kubelet │  │• kubelet │               │
│  │• Docker  │  │• Docker  │               │
│  │• Pods    │  │• Pods    │               │
│  └──────────┘  └──────────┘               │
│     ▲              ▲                       │
│     └──────┬───────┘                       │
│            │                               │
│  FK Stack Pods (distributed):            │
│  • fk-mongodb                             │
│  • fk-api (replicas 2-4, HPA)            │
│  • fk-frontend                            │
│  • cert-manager                           │
│  • argocd                                 │
│                                             │
└─────────────────────────────────────────────┘
```

## Files Structure

```
vagrant/
├── Vagrantfile                    # VM configuration (3 nodes)
├── 01-base-setup.sh               # Docker, iptables, swap disable
├── 02-kubeadm-install.sh          # Install kubeadm tools
├── 03-control-plane-init.sh       # Initialize control plane + Calico
├── 04-worker-join.sh              # Join workers to cluster
├── 05-deploy-argocd.sh            # Deploy ArgoCD + cert-manager + FK stack
└── kubeadm-config/                # Shared folder for join commands
    └── join-command.sh            # Generated by control plane init
```

## Extra Features Included

✅ **HTTPS with cert-manager** - Self-signed certificates for local testing
✅ **Extra worker nodes** - 2 workers for scaling demo
✅ **Healthchecks** - Liveness/readiness probes in API deployment
✅ **HPA** - Horizontal Pod Autoscaler for API (2-4 replicas)
✅ **Kubeadm** - Real Kubernetes cluster (not minikube)
✅ **ArgoCD** - GitOps automation via Helm Chart (+4/20 points)

## Tips

- **RAM requirement**: 7GB total (3+2+2 per VM)
- **Disk requirement**: ~10GB (Ubuntu image + VM disk)
- **Network**: VMs use private network 192.168.56.0/24
- **Provisioning time**: 15-20 minutes for first `vagrant up`

For updates: just run `vagrant provision`
