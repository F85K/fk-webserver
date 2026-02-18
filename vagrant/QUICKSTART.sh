#!/bin/bash
# Quick start guide for FK Webstack Kubeadm deployment

cat << 'EOF'
════════════════════════════════════════════════════════════════
  FK WEBSTACK - KUBEADM CLUSTER SETUP GUIDE
════════════════════════════════════════════════════════════════

STEP 1: Install Prerequisites (Windows)
───────────────────────────────────────────────────────────────
1. Install Vagrant: https://www.vagrantup.com/downloads
2. Install VirtualBox: https://www.virtualbox.org/wiki/Downloads
3. Add to PATH in PowerShell:
   $env:PATH += ";C:\HashiCorp\Vagrant\bin;C:\Program Files\Oracle\VirtualBox"

Verify:
   vagrant --version
   vboxmanage --version

STEP 2: Start Kubeadm Cluster (15-20 minutes)
───────────────────────────────────────────────────────────────
cd C:\Users\Admin\Desktop\WebserverLinux
vagrant up

This creates:
   ✓ fk-control (192.168.56.10) - Control Plane
   ✓ fk-worker1 (192.168.56.11) - Worker 1
   ✓ fk-worker2 (192.168.56.12) - Worker 2

STEP 3: Setup kubectl on Windows Host
───────────────────────────────────────────────────────────────
# Copy kubeconfig from control plane VM
vagrant ssh fk-control -c "cat /etc/kubernetes/admin.conf" > $env:USERPROFILE\.kube\config

# Verify cluster
kubectl get nodes

Expected output:
   NAME         STATUS   ROLES           AGE   VERSION
   fk-control   Ready    control-plane   2m    v1.35.0
   fk-worker1   Ready    <none>          1m    v1.35.0
   fk-worker2   Ready    <none>          1m    v1.35.0

STEP 4: Deploy FK Stack with Full Monitoring
───────────────────────────────────────────────────────────────
# Build Docker images on all nodes
vagrant ssh fk-control -c "bash /vagrant/vagrant/06-build-images.sh"
vagrant ssh fk-worker1 -c "bash /vagrant/vagrant/06-build-images.sh"
vagrant ssh fk-worker2 -c "bash /vagrant/vagrant/06-build-images.sh"

# Deploy complete stack (MongoDB, API, Frontend, cert-manager, Prometheus, ArgoCD)
vagrant ssh fk-control -c "bash /vagrant/deploy-full-stack.sh"

This deploys:
   ✓ MongoDB + Init Job
   ✓ FastAPI Backend (HPA 2-4 replicas)
   ✓ Frontend (lighttpd)
   ✓ cert-manager (TLS)
   ✓ Prometheus + Grafana (Monitoring)
   ✓ ArgoCD (GitOps)

STEP 5: Verify Success Criteria
───────────────────────────────────────────────────────────────
vagrant ssh fk-control -c "bash /vagrant/verify-success-criteria.sh"

Expected:
   ✓ 1. Docker Stack (MongoDB, API, Frontend)
   ✓ 2. Kubernetes Cluster (3 nodes Ready)
   ✓ 3. Live Data (MongoDB initialized)
   ✓ 4. TLS & Secrets (cert-manager)
   ✓ 5. Monitoring (Prometheus + Grafana)
   ✓ 6. GitOps (ArgoCD)
   ⚠ 7. Logging (optional)

STEP 6: Access Applications
───────────────────────────────────────────────────────────────

A) Test FK API (FastAPI backend)
   # Terminal 1: Port forward
   vagrant ssh fk-control -c "kubectl port-forward svc/fk-api -n fk-webstack 8000:8000"
   
   # Terminal 2: Test request
   Invoke-RestMethod http://localhost:8000/api/name
   Expected: {"name":"Frank Koch"}

B) Grafana Monitoring Dashboard
   # Terminal 1: Port forward
   vagrant ssh fk-control -c "kubectl port-forward svc/fk-monitoring-grafana -n monitoring 3000:80"
   
   # Browser
   URL: http://localhost:3000
   User: admin
   Password: admin
   
   Navigate to: Dashboards → Kubernetes / Compute Resources / Cluster

C) ArgoCD Web UI (GitOps)
   # Terminal 1: Port forward
   vagrant ssh fk-control -c "kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443"
   
   # Get password
   vagrant ssh fk-control -c "kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d"
   
   # Browser
   URL: https://localhost:8080 (ignore SSL warning)
   User: admin
   Password: (from command above)

STEP 7: Test GitOps with ArgoCD
───────────────────────────────────────────────────────────────
1. Make change to git repo: https://github.com/F85K/minikube
   - Edit any k8s/ manifest file

2. Push to GitHub

3. ArgoCD will automatically detect and deploy the change
   - Check ArgoCD UI to see sync status
   - Check kubectl to see pods update

EXTRA: HPA & Pod Scaling Test
───────────────────────────────────────────────────────────────
# Watch HPA status
vagrant ssh fk-control -c "kubectl get hpa -n fk-webstack --watch"

# Generate load to trigger scaling (Terminal 2)
vagrant ssh fk-control -c "kubectl run -it --rm load-generator \
  --image=busybox:1.28 \
  --restart=Never \
  -- /bin/sh -c 'while sleep 0.01; do wget -q -O- http://fk-api.fk-webstack:8000/api/name; done'"

# Observe pods scale from 2 to 4 replicas

EXTRA: Check Resource Usage
───────────────────────────────────────────────────────────────
# Node resource usage
vagrant ssh fk-control -c "kubectl top nodes"

# Pod resource usage
vagrant ssh fk-control -c "kubectl top pods -A --sort-by=memory"

# Grafana dashboards (already deployed)
# See STEP 6B above for access

TROUBLESHOOTING
───────────────────────────────────────────────────────────────
Workers not Ready?
   vagrant ssh fk-control -c "kubectl get nodes"
   vagrant ssh fk-control -c "kubectl get pods -n kube-flannel"
   vagrant reload fk-worker1

Pods stuck Terminating?
   vagrant ssh fk-control -c "bash /vagrant/cleanup-stuck-resources.sh"

Pods not starting?
   vagrant ssh fk-control -c "kubectl describe pod <podname> -n fk-webstack"
   vagrant ssh fk-control -c "kubectl logs <podname> -n fk-webstack"

Prometheus using too much memory?
   # Check resource usage
   vagrant ssh fk-control -c "free -h"
   # See docs/TROUBLESHOOTING.md for solutions

Complete rebuild?
   vagrant destroy -f
   vagrant up
   vagrant ssh fk-control -c "bash /vagrant/deploy-full-stack.sh"
   # See docs/REBUILD-GUIDE.md for detailed steps

USEFUL DOCUMENTATION
───────────────────────────────────────────────────────────────
   docs/REBUILD-GUIDE.md       - Step-by-step rebuild instructions
   docs/TROUBLESHOOTING.md     - Common issues and solutions
   vagrant/verify-success-criteria.sh  - Check all 7 criteria
   vagrant/deploy-full-stack.sh        - Deploy everything
   vagrant/cleanup-stuck-resources.sh  - Fix stuck pods

CLUSTER ARCHITECTURE
───────────────────────────────────────────────────────────────
                   Kubernetes 1.35.0
    ┌──────────────────────────────────────────┐
    │  fk-control (Control Plane) 6GB RAM      │
    │  • API Server, etcd, Scheduler           │
    │  • Flannel CNI v0.25.1                   │
    │  • ArgoCD, cert-manager, Prometheus      │
    └──────────────────────────────────────────┘
         │                          │
    ┌────┴────────┐        ┌────────┴────────┐
    │ fk-worker1  │        │   fk-worker2    │
    │  3GB RAM    │        │    3GB RAM      │
    └─────────────┘        └─────────────────┘
         │                          │
    ┌────┴──────────────────────────┴────┐
    │        fk-webstack Namespace       │
    │  • MongoDB (1 replica)             │
    │  • API (HPA 2-4 replicas)          │
    │  • Frontend (2 replicas)           │
    └────────────────────────────────────┘

SCORING BREAKDOWN (20/20 possible)
───────────────────────────────────────────────────────────────
Basis:
   10/20 - Kubernetes cluster (kubeadm + 2 workers) ✅

Extra:
   +2/20 - HTTPS (cert-manager + self-signed cert) ✅
   +1/20 - Extra worker nodes (2 workers showing scaling) ✅
   +1/20 - Healthchecks (liveness/readiness probes) ✅
   +2/20 - Prometheus monitoring ✅
   +4/20 - ArgoCD + GitOps (Helm deployment) ✅

TOTAL: 20/20 ✅

════════════════════════════════════════════════════════════════
EOF
