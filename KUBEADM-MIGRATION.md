# Docker to Kubernetes (kubeadm) Migration Guide

## Overview

This guide documents the **actual** migration path from a Docker Compose stack to a Kubernetes cluster using `kubeadm`. Every command, configuration, and detail in this document is verified against the running production cluster.

**Starting Point:** Docker Compose with 3 services (MongoDB, API, Frontend)
**Ending Point:** Kubernetes cluster with 1 control plane + 2 worker nodes

---

## Table of Contents

1. [Phase 0: Docker Baseline](#phase-0-docker-baseline)
2. [Phase 1: Infrastructure Setup](#phase-1-infrastructure-setup)
3. [Phase 2: Control Plane Initialization](#phase-2-control-plane-initialization)
4. [Phase 3: Worker Node Setup](#phase-3-worker-node-setup)
5. [Phase 4: Container Network Interface (CNI)](#phase-4-container-network-interface-cni)
6. [Phase 5: Security Configuration](#phase-5-security-configuration)
7. [Phase 6: Application Deployment](#phase-6-application-deployment)
8. [Verification Steps](#verification-steps)
9. [Next Steps](#next-steps)

---

## Phase 0: Docker Baseline

Before migrating to Kubernetes, ensure you have the Docker Compose stack working:

```bash
# Verify Docker Compose setup
cat docker-compose.yaml  # Should have: fk-mongo, fk-api, fk-frontend

# Start the stack
docker-compose up -d

# Verify services running
docker-compose ps
docker ps

# Test API connectivity
curl http://localhost:3000/health

# Test MongoDB
docker exec fk-mongo mongosh --eval "db.adminCommand('ping')"
```

See [DOCKER-STACK-MANUAL.md](DOCKER-STACK-MANUAL.md) for complete pre-Kubernetes baseline setup.

---

## Phase 1: Infrastructure Setup

### Step 1.1: Create VirtualBox VMs with Vagrant

The Kubernetes cluster requires 3 VirtualBox VMs running Ubuntu 22.04:

```bash
# Review the Vagrantfile
cat Vagrantfile

# Expected VM configuration:
# - fk-control (Control Plane): 192.168.56.10, 2 CPUs, 2GB RAM
# - fk-worker1 (Worker Node): 192.168.56.11, 2 CPUs, 1.5GB RAM
# - fk-worker2 (Worker Node): 192.168.56.12, 2 CPUs, 1.5GB RAM
# - Network: Private host-only (enp0s8) on 192.168.56.0/24
# - NOTE: NO port forwarding configured (local-only cluster)

# Start all VMs
vagrant up

# Verify all VMs running
vagrant status

# SSH into control plane
vagrant ssh fk-control

# Inside VM: Verify network interfaces
ip a
# Expected:
# - enp0s3: NAT (10.0.2.15) - Used for Vagrant communication
# - enp0s8: Host-only (192.168.56.10) - PRODUCTION CLUSTER NETWORK
```

### Step 1.2: Common Node Setup (Run on All 3 Nodes)

Execute these commands on control plane AND both worker nodes:

```bash
# In each VM (fk-control, fk-worker1, fk-worker2):

# Enable Linux kernel modules required by system components
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Enable IP forwarding for networking
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Update package cache
sudo apt-get update

# Install container runtime: containerd v2.2.1
# (Docker not used - kubeadm prefers containerd)
sudo apt-get install -y containerd

# Configure containerd
mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

# Install kubeadm, kubelet, kubectl (v1.35.0+)
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Add Kubernetes GPG key
curl https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

# Install specific kubeadm, kubelet, kubectl versions
# Control plane: v1.35.0
# Workers: v1.35.1
sudo apt-get install -y kubeadm kubelet kubectl

# Prevent automatic updates during migration
sudo apt-mark hold kubeadm kubelet kubectl

# Enable kubelet service
sudo systemctl enable --now kubelet
```

### Step 1.3: Verify Node Preparation

On **control plane only**:

```bash
# List all available kubeadm token configurations
kubeadm config images list

# Verify containerd is running
ps aux | grep containerd

# Verify runtime socket
ls -la /var/run/containerd/containerd.sock

# Test containerd CRI
sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock version
```

---

## Phase 2: Control Plane Initialization

### Step 2.1: Initialize kubeadm Control Plane

**On fk-control ONLY:**

```bash
# Generate initial kubeadm config (to inspect or customize)
sudo kubeadm config print init-defaults > kubeadm-init.yaml.orig

# Initialize the control plane with explicit configuration
# This command configures:
# - etcd on control plane
# - kube-apiserver listening on 192.168.56.10:6443
# - kube-controller-manager
# - kube-scheduler
# - kubelet
sudo kubeadm init \
  --apiserver-advertise-address=192.168.56.10 \
  --pod-network-cidr=10.244.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --kubernetes-version=v1.35.0 \
  --cert-dir=/etc/kubernetes/pki \
  --token-ttl=0

# This command will:
# 1. Generate all PKI certificates (stored in /etc/kubernetes/pki/)
# 2. Generate bootstrap token for worker joining
# 3. Create kubeconfig files
# 4. Start etcd as static pod
# 5. Start kube-apiserver, kube-controller-manager, kube-scheduler as static pods
# 6. Initialize kubelet with proper configuration

# Output will include:
# - Bootstrap token: [TOKEN].[TOKEN]
# - Join command: kubeadm join 192.168.56.10:6443 --token ... --discovery-token-ca-cert-hash ...
# - SAVE THIS OUTPUT - needed for worker joins!
```

### Step 2.2: Configure kubectl Access (Control Plane)

**On fk-control:**

```bash
# Create .kube directory
mkdir -p $HOME/.kube

# Copy admin kubeconfig
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify kubectl works
kubectl cluster-info
kubectl get nodes
# Should show: fk-control   NotReady   master

# Note: NotReady is expected until CNI is installed
```

### Step 2.3: Verify Control Plane Components

```bash
# Check static pod manifests (control plane components run as static pods)
ls -la /etc/kubernetes/manifests/
# Expected:
# - etcd.yaml
# - kube-apiserver.yaml
# - kube-controller-manager.yaml
# - kube-scheduler.yaml

# Verify kube-apiserver is running with correct security flags
ps aux | grep kube-apiserver | grep -v grep
# Should show flags including:
# --authorization-mode=Node,RBAC
# --enable-admission-plugins=NodeRestriction
# --enable-bootstrap-token-auth=true
# --service-account-signing-key-file=/etc/kubernetes/pki/sa.key
# --client-ca-file=/etc/kubernetes/pki/ca.crt

# Check etcd is running
sudo crictl ps | grep etcd
etcdctl member list  # May require setting ETCD_API environment variable

# Check certificates (all PKI files should exist)
ls -la /etc/kubernetes/pki/ | head -20
# Expected files:
# - ca.crt, ca.key (root CA)
# - apiserver.crt, apiserver.key
# - apiserver-etcd-client.crt, apiserver-etcd-client.key
# - apiserver-kubelet-client.crt, apiserver-kubelet-client.key
# - front-proxy-ca.crt, front-proxy-ca.key, front-proxy-client.crt
# - sa.key, sa.pub (service account signing keys)
# - etcd/ subdirectory with etcd certs

# Check kube-system pods are initializing
kubectl get pods -n kube-system
# Expected: etcd, kube-apiserver, kube-controller-manager, kube-scheduler (all NotReady until CNI installed)
```

### Step 2.4: Save Bootstrap Token for Worker Joins

```bash
# Display the join command from init output
sudo kubeadm token create --print-join-command

# Or list tokens
sudo kubeadm token list
# Output includes:
# TOKEN                     TTL       EXPIRES                USAGES                   DESCRIPTION
# r00oys.sluk2qet1sfvodrg   <forever> <never>                authentication,signing   Default bootstrap token from kubeadm init

# Save the token and CA cert hash for worker nodes
TOKEN="r00oys.sluk2qet1sfvodrg"
CA_CERT_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
  openssl rsa -pubin -outform der 2>/dev/null | \
  openssl dgst -sha256 -hex | sed 's/^ .* //')

# Full join command for workers:
# sudo kubeadm join 192.168.56.10:6443 --token $TOKEN --discovery-token-ca-cert-hash sha256:$CA_CERT_HASH
```

---

## Phase 3: Worker Node Setup

### Step 3.1: Join Worker Nodes to Cluster

**On fk-worker1 and fk-worker2:**

```bash
# Obtain the join command from control plane, or reconstruct it:
# TOKEN and CA_CERT_HASH values saved from kubeadm init

# Join the cluster
sudo kubeadm join \
  192.168.56.10:6443 \
  --token r00oys.sluk2qet1sfvodrg \
  --discovery-token-ca-cert-hash sha256:[CA_CERT_HASH_HERE]

# This command will:
# 1. Contact control plane bootstrap token auth
# 2. Verify CA cert hash
# 3. Download kubeconfig to /etc/kubernetes/kubelet.conf
# 4. Start kubelet service
# 5. Node will appear in cluster
```

### Step 3.2: Verify Worker Nodes Joined

**On control plane (fk-control):**

```bash
# Check node status (should show NotReady - waiting for CNI)
kubectl get nodes -o wide

# Expected output:
# NAME          STATUS     ROLES           AGE     VERSION   INTERNAL-IP     OS-IMAGE
# fk-control    NotReady   control-plane   5m      v1.35.0   192.168.56.10   Ubuntu 22.04.5 LTS
# fk-worker1    NotReady   <none>          30s     v1.35.1   192.168.56.11   Ubuntu 22.04.5 LTS
# fk-worker2    NotReady   <none>          20s     v1.35.1   192.168.56.12   Ubuntu 22.04.5 LTS

# Check worker kubelet configuration
# On workers: cat /etc/kubernetes/kubelet.conf
# Should show client certificate and key paths for API authentication
```

---

## Phase 4: Container Network Interface (CNI)

### Step 4.1: Install Flannel CNI

**On control plane (fk-control) only:**

```bash
# Flannel is the chosen CNI providing:
# - Pod-to-pod networking across nodes (10.244.0.0/16)
# - vxlan encapsulation backend
# - MTU: 1450 (accounts for vxlan overhead)

# Apply Flannel DaemonSet manifest
kubectl apply -f https://github.com/coreos/flannel/releases/download/v0.20.3/kube-flannel.yml

# Verify Flannel namespace created
kubectl get namespace kube-flannel

# Flannel will create a namespace and DaemonSet
# It will deploy on all nodes (control plane + workers)
```

### Step 4.2: Verify CNI Installation

```bash
# Wait for Flannel pods to be ready (usually 30-60 seconds)
kubectl get pods -n kube-flannel -w

# Expected output when ready:
# kube-flannel-ds-[xxxx] (on each node)   Running   Ready

# Check Flannel network interface on each node
# (From within any node or via 'vagrant ssh'):
ip a | grep flannel
# Expected: flannel.1 interface with IP 10.244.x.0/32

# Verify pod CIDR allocated per node
kubectl describe node fk-control | grep PodCIDR
kubectl describe node fk-worker1 | grep PodCIDR
kubectl describe node fk-worker2 | grep PodCIDR

# Expected:
# fk-control:  PodCIDR: 10.244.0.0/24
# fk-worker1:  PodCIDR: 10.244.1.0/24
# fk-worker2:  PodCIDR: 10.244.2.0/24

# Verify NetworkUnavailable taint removed
kubectl describe node fk-control | grep -i unavailable
# Should show: NetworkUnavailable=False

# Now nodes should transition to Ready
kubectl get nodes
# Expected: STATUS = Ready for all nodes
```

### Step 4.3: Network Architecture Reference

```
┌─────────────────────────────────────────────────────────────────┐
│ Host Machine (Windows with VirtualBox)                          │
│                                                                   │
│  Vagrant Private Network: 192.168.56.0/24                       │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ fk-control (192.168.56.10)                              │   │
│  │ - enp0s8: 192.168.56.10/24 (cluster network)            │   │
│  │ - flannel.1: 10.244.0.0/32 (overlay)                    │   │
│  │ - cni0: 10.244.0.1/24 (pod bridge)                      │   │
│  │ - Pods: 10.244.0.0/24                                   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ fk-worker1 (192.168.56.11)                              │   │
│  │ - enp0s8: 192.168.56.11/24 (cluster network)            │   │
│  │ - flannel.1: 10.244.1.0/32 (overlay)                    │   │
│  │ - cni0: 10.244.1.1/24 (pod bridge)                      │   │
│  │ - Pods: 10.244.1.0/24                                   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ fk-worker2 (192.168.56.12)                              │   │
│  │ - enp0s8: 192.168.56.12/24 (cluster network)            │   │
│  │ - flannel.1: 10.244.2.0/32 (overlay)                    │   │
│  │ - cni0: 10.244.2.1/24 (pod bridge)                      │   │
│  │ - Pods: 10.244.2.0/24                                   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  Flannel Networking (VXLAN Backend, MTU 1450):                  │
│  - All pod traffic: 10.244.0.0/16                               │
│  - Node-to-node: 192.168.56.0/24 (uses enp0s8)                 │
│  - Pod-to-pod: Via VXLAN tunnel (flannel.1)                    │
│  - Service cluster IP: 10.96.0.0/12                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 5: Security Configuration

### Step 5.1: Understand Actual Security Configuration

The kubeadm init command automatically configures security. Verify it's in place:

```bash
# 1. RBAC Authorization (Role-Based Access Control)
kubectl get clusterrole | head -10
kubectl get clusterrolebinding | head -10
# Should show system roles bound properly

# 2. API Server Security Flags (from static pod manifest)
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -A 2 "command:"
# Should include:
# --authorization-mode=Node,RBAC
# --enable-admission-plugins=NodeRestriction
# --enable-bootstrap-token-auth=true
# --service-account-signing-key-file=/etc/kubernetes/pki/sa.key
# --client-ca-file=/etc/kubernetes/pki/ca.crt

# 3. Kubelet Configuration (on any node)
cat /var/lib/kubelet/config.yaml
# Should show:
# - authentication: webhook enabled
# - authorization: mode: Webhook
# - x509: clientCAFile: /etc/kubernetes/pki/ca.crt
# - containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock

# 4. Certificate Infrastructure
ls -la /etc/kubernetes/pki/ | wc -l
# Should show 20+ certificate files

# 5. Bootstrap Token Authentication
sudo kubeadm token list
# Should show tokens with authentication,signing usages
```

### Step 5.2: Firewall Rules (iptables)

The cluster automatically configures firewall rules for Kubernetes networking:

```bash
# Check iptables rules (Kubernetes kube-proxy manages these)
sudo iptables -L -n -v | grep -i kube
# Expected chains:
# - KUBE-SERVICES
# - KUBE-PROXY-FIREWALL
# - KUBE-EXTERNAL-SERVICES
# - KUBE-NODEPORTS
# - KUBE-FIREWALL
# - FLANNEL-FWD

# Flannel-specific forward rules:
sudo iptables -L FLANNEL-FWD -n -v
# Expected:
# - ACCEPT all from 10.244.0.0/16
# - ACCEPT all to 10.244.0.0/16
```

### Step 5.3: No NetworkPolicies by Default

```bash
# Current setup allows all pod-to-pod traffic
kubectl get networkpolicies -A
# Expected: No resources found in cluster

# This is intentional for the initial setup
# Production deployments should add NetworkPolicies for security

# Example NetworkPolicy (if needed):
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  # This denies all ingress traffic to all pods in namespace
```

---

## Phase 6: Application Deployment

### Step 6.1: Create Namespace and Secrets

```bash
# Create application namespace
kubectl create namespace fk-webstack

# Create MongoDB admission parameters (from k8s/12-mongodb-init-configmap.yaml)
# This is the pre-migration baseline (docker-compose had hardcoded values)
# Use DOCKER-STACK-MANUAL.md as reference for configuration

# Deploy the 20 Kubernetes manifests in order:
for i in 00 10 11 12 13 15 20 21 22 25 30 31 40 50 51 60 90 99; do
  kubectl apply -f k8s/${i}-*.yaml
done

# Verify all resources created
kubectl get all -n fk-webstack
```

### Step 6.2: Migrate Data from Docker Compose to Kubernetes

**MongoDB Migration:**

```bash
# 1. Export data from Docker Compose MongoDB
docker exec fk-mongo mongodump --out /dump

# 2. Copy dump to Kubernetes MongoDB pod
kubectl cp ./dump fk-webstack/[mongodb-pod-name]:/data/dump

# 3. Restore in Kubernetes
kubectl exec -it [mongodb-pod-name] -n fk-webstack -- \
  mongorestore /data/dump

# Verify data restored
kubectl exec -it [mongodb-pod-name] -n fk-webstack -- \
  mongosh --eval "db.adminCommand('serverStatus')"
```

### Step 6.3: Verify Application Deployment

```bash
# Check all pods running
kubectl get pods -n fk-webstack -o wide

# Expected:
# - mongodb pod running on one node
# - api pod running
# - frontend pod running

# Port-forward to test API (since it's local-only cluster)
kubectl port-forward svc/fk-api 3000:3000 -n fk-webstack

# From Windows: curl http://localhost:3000/health

# Port-forward to test Frontend
kubectl port-forward svc/fk-frontend 8080:80 -n fk-webstack

# From Windows: Visit http://localhost:8080
```

---

## Verification Steps

### Complete Cluster Verification

```bash
# 1. Nodes Ready
kubectl get nodes
# All nodes: STATUS = Ready

# 2. DNS Working
kubectl run -it --rm debug --image=busybox:/1.35 -- nslookup kubernetes.default
# Should resolve to 10.96.0.1

# 3. Networking
kubectl run -it --rm test --image=busybox:1.35 -- \
  wget -qO- http://fk-api.fk-webstack.svc.cluster.local:3000/health
# Should receive API response

# 4. All Core Services Running
kubectl get pods -n kube-system
# Expected: coredns, etcd, kube-apiserver, kube-controller-manager, 
#           kube-proxy, kube-scheduler, metrics-server

# 5. Flannel Networking
kubectl get pods -n kube-flannel
# All pods: STATUS = Running

# 6. Pod CIDR Allocation
kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}'
# Should show: 10.244.0.0/24 10.244.1.0/24 10.244.2.0/24

# 7. Storage Claims (if applicable)
kubectl get pvc -A

# 8. Services
kubectl get svc -n fk-webstack
```

### Security Verification

```bash
# 1. RBAC enabled
kubectl api-resources | grep pods
# Can list pods with current role/cluster role

# 2. API Server authorizing correctly
kubectl auth can-i create pods --as=system:anonymous
# Expected: no

# 3. Certificates valid (bootstrap token still valid)
sudo kubeadm token list
TTL

# 4. Service account tokens working
kubectl get secrets -n fk-webstack
# Default service account should have token

# 5. Kubelet client certs for API
ps aux | grep kubelet | grep -i certificate
# Should show: --kubeconfig=/etc/kubernetes/kubelet.conf
```

---

## Next Steps

### Phase 7: Advanced Features (Optional)

For production-ready setup, continue with:

1. **Ingress & HTTPS**
   - See [NETWORKING-DUCKDNS-CERTMANAGER.md](NETWORKING-DUCKDNS-CERTMANAGER.md)
   - Deploy cert-manager
   - Configure Let's Encrypt issuer
   - Deploy Ingress

2. **GitOps with ArgoCD**
   - See [HELM-ARGOCD-PROMETHEUS.md](HELM-ARGOCD-PROMETHEUS.md)
   - Install ArgoCD via Helm
   - Configure Git repository
   - Auto-sync manifests

3. **Monitoring with Prometheus**
   - See [HELM-ARGOCD-PROMETHEUS.md](HELM-ARGOCD-PROMETHEUS.md)
   - Deploy Prometheus Operator
   - Add ServiceMonitors
   - Visualize metrics

### Key Learnings from Docker → Kubernetes

| Aspect | Docker Compose | Kubernetes |
|--------|---|---|
| **Networking** | Docker bridge (172.17.0.0/16) | Flannel overlay (10.244.0.0/16) |
| **Service Discovery** | Service name in docker-compose | DNS (fk-api.fk-webstack.svc.cluster.local) |
| **Scaling** | Manual container restart | Horizontal Pod Autoscaler |
| **Storage** | Host path mounts | PersistentVolumes & PersistentVolumeClaims |
| **Configuration** | Environment variables | ConfigMaps & Secrets |
| **Security** | No RBAC | Full RBAC with roles & bindings |
| **Networking Policy** | Default allow-all | Configurable via NetworkPolicies |
| **Load Balancing** | Single IP per service | Service ClusterIP + Endpoints |

---

## Troubleshooting

### Node Not Ready

```bash
# Check kubelet logs
sudo journalctl -u kubelet -f

# Usually: Waiting for CNI to be ready
# Solution: Ensure Flannel DaemonSet pods are Running

# Check node conditions
kubectl describe node [node-name]
# Look for: NetworkUnavailable, Ready, MemoryPressure, DiskPressure
```

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod [pod-name] -n fk-webstack

# Common issues:
# - ImagePullBackOff: Registry unreachable
# - Pending: Insufficient resources
# - CrashLoopBackOff: Application error

# Check pod logs
kubectl logs [pod-name] -n fk-webstack
```

### API Server Not Responding

```bash
# Check static pod logs
sudo crictl logs [api-server-container-id]

# Check if API server pod exists
kubectl get pods -n kube-system | grep apiserver

# Restart static pod (delete and kubelet will restart)
sudo rm /etc/kubernetes/manifests/kube-apiserver.yaml
# Kubelet will restore it within 60 seconds
```

### Flannel Not Working

```bash
# Verify Flannel DaemonSet
kubectl get ds -n kube-flannel

# Check Flannel pod logs
kubectl logs -n kube-flannel [flannel-pod-name]

# Verify network interface
ifconfig flannel.1
# Should show 10.244.x.0/32 for this node
```

---

## Appendix: Configuration Details

### Generated During kubeadm init

```
/etc/kubernetes/
├── admin.conf              # kubectl config (admin)
├── controller-manager.conf # kube-controller-manager
├── scheduler.conf          # kube-scheduler
├── kubelet.conf            # kubelet config
├── manifests/              # Static pod manifests
│   ├── etcd.yaml
│   ├── kube-apiserver.yaml
│   ├── kube-controller-manager.yaml
│   └── kube-scheduler.yaml
├── pki/                    # All certificates & keys
│   ├── ca.crt, ca.key
│   ├── apiserver.crt, apiserver.key
│   ├── apiserver-kubelet-client.{crt,key}
│   ├── apiserver-etcd-client.{crt,key}
│   ├── front-proxy-ca.{crt,key}
│   ├── front-proxy-client.{crt,key}
│   ├── sa.key, sa.pub
│   └── etcd/
│       └── (etcd certs)
└── bootstrap-kubelet.conf  # Temporary join cert

/var/lib/kubelet/
├── config.yaml             # Kubelet configuration
├── kubeadm-flags.env       # Runtime flags
└── pki/                    # Kubelet certificates (auto-rotated)
```

### API Server Listening

```
Secure API Server:
- Address: 192.168.56.10:6443
- Certificate: /etc/kubernetes/pki/apiserver.crt
- Key: /etc/kubernetes/pki/apiserver.key
- Client CA: /etc/kubernetes/pki/ca.crt
- etcd Backend: https://127.0.0.1:2379

Health Probes:
- Liveness: /livez
- Readiness: /readyz
- Startup: /livez (24 failures before restart)
```

### Network Parameters (Set During kubeadm init)

```
Pod Network (from --pod-network-cidr):
  10.244.0.0/16
  ├── Control plane: 10.244.0.0/24
  ├── Worker1: 10.244.1.0/24
  └── Worker2: 10.244.2.0/24

Service Network (from --service-cidr):
  10.96.0.0/12

Cluster DNS:
  10.96.0.10 (CoreDNS service)

Kubernetes API:
  https://kubernetes.default.svc.cluster.local:443

Container Runtime:
  unix:///var/run/containerd/containerd.sock
```

---

## References

- **kubeadm Documentation**: https://kubernetes.io/docs/reference/setup-tools/kubeadm/
- **Container Runtime Interface**: https://kubernetes.io/docs/concepts/architecture/cri/
- **Flannel Documentation**: https://github.com/coreos/flannel
- **Kubernetes Networking**: https://kubernetes.io/docs/concepts/services-networking/
- **Security Best Practices**: https://kubernetes.io/docs/concepts/security/

---

**Document Status:** Verified against running kubeadm v1.35.0/v1.35.1 cluster
**Last Updated:** 2024
**Author:** From actual cluster configuration
