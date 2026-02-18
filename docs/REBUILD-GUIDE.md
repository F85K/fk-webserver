# FK Webstack - Complete Rebuild Guide

This guide provides step-by-step instructions to rebuild the entire FK Webstack from scratch after destroying VMs.

## Prerequisites

- VirtualBox 7.x installed
- Vagrant 2.x installed  
- 12GB RAM available
- ~30GB disk space
- Internet connection for downloading images

## Rebuild Steps

### Step 1: Clean Existing State

```powershell
# Destroy all VMs
cd C:\Users\Admin\Desktop\WebserverLinux
vagrant destroy -f

# Clean kubeadm state
Remove-Item -Path "kubeadm-config\*" -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "kubeadm-config" -Force

# Verify all VMs are gone
vagrant status
```

**Expected Output:**
```
Current machine states:
fk-control                not created (virtualbox)
fk-worker1                not created (virtualbox)
fk-worker2                not created (virtualbox)
```

---

### Step 2: Start VMs (10-15 minutes)

```powershell
vagrant up
```

**What Happens:**
1. **fk-control** (6GB RAM, 4 CPUs):
   - Installs Docker, containerd
   - Installs kubeadm, kubelet v1.35.0
   - Initializes control plane
   - Installs Flannel CNI v0.25.1
   - Waits for API server to be ready
   - Creates join token for workers

2. **fk-worker1** (3GB RAM, 2 CPUs):
   - Waits for control plane ready marker
   - Waits for Flannel CNI ready marker
   - Joins cluster with kubeadm token
   - Restarts kubelet to load CNI

3. **fk-worker2** (3GB RAM, 2 CPUs):
   - Same as worker1

**Progress Monitoring:**
Open a second PowerShell terminal:
```powershell
# Watch VM status
vagrant status

# Once control plane is up (after ~5 minutes)
vagrant ssh fk-control -c "kubectl get nodes"
```

**Expected Timeline:**
- 0-3 min: Base setup, Docker installation
- 3-5 min: kubeadm installation
- 5-8 min: Control plane initialization
- 8-10 min: Flannel CNI deployment
- 10-15 min: Workers join cluster

---

### Step 3: Verify Cluster Health

```powershell
# Check all nodes are Ready
vagrant ssh fk-control -c "kubectl get nodes"
```

**Expected Output:**
```
NAME         STATUS   ROLES           AGE   VERSION
fk-control   Ready    control-plane   10m   v1.35.0
fk-worker1   Ready    <none>          8m    v1.35.0
fk-worker2   Ready    <none>          8m    v1.35.0
```

**If Workers Not Ready:**
```powershell
# Check Flannel pods
vagrant ssh fk-control -c "kubectl get pods -n kube-flannel"

# Reload worker if needed
vagrant reload fk-worker1
```

---

### Step 4: Build Docker Images (2-3 minutes)

```powershell
# Build and load images on all nodes
vagrant ssh fk-control -c "bash /vagrant/vagrant/06-build-images.sh"
vagrant ssh fk-worker1 -c "bash /vagrant/vagrant/06-build-images.sh"
vagrant ssh fk-worker2 -c "bash /vagrant/vagrant/06-build-images.sh"
```

**What Gets Built:**
- `fk-api:latest` - FastAPI application
- `fk-frontend:latest` - lighttpd web server

**Verification:**
```powershell
vagrant ssh fk-control -c "sudo crictl images | grep fk-"
```

---

### Step 5: Deploy Full Stack (5-8 minutes)

```powershell
vagrant ssh fk-control -c "bash /vagrant/deploy-full-stack.sh"
```

**Components Deployed:**
1. **FK Webstack Application:**
   - Namespace: fk-webstack
   - MongoDB (1 replica)
   - MongoDB init job
   - API (HPA 2-4 replicas)
   - Frontend (2 replicas)

2. **cert-manager (TLS):**
   - Namespace: cert-manager
   - cert-manager controller
   - webhook
   - cainjector
   - selfsigned-issuer

3. **Prometheus Stack (Monitoring):**
   - Namespace: monitoring
   - Prometheus server (with resource limits)
   - Grafana
   - kube-state-metrics
   - node-exporter (on all nodes)

4. **ArgoCD (GitOps):**
   - Namespace: argocd
   - ArgoCD server
   - ArgoCD controller
   - ArgoCD repo-server
   - Redis

**Progress Monitoring:**
Open another terminal:
```powershell
vagrant ssh fk-control -c "kubectl get pods -A -w"
```

---

### Step 6: Verify Success Criteria

```powershell
vagrant ssh fk-control -c "bash /vagrant/verify-success-criteria.sh"
```

**Expected Output:**
```
======================================
FK Webstack Success Criteria Verification
======================================

1. Docker Stack (containers running in Kubernetes)
   ✓ PASS - MongoDB: 1, API: 2, Frontend: 2

2. Kubernetes Cluster (3 nodes: 1 control + 2 workers)
   ✓ PASS - All 3 nodes Ready

3. Live Data (MongoDB with initial data)
   ✓ PASS - MongoDB init job completed successfully

4. TLS & Secrets (cert-manager + issuers)
   ✓ PASS - cert-manager running (3 pods), issuer configured

5. Monitoring (Prometheus, Grafana, metrics)
   ✓ PASS - Prometheus: 1, Grafana: 1

6. GitOps (ArgoCD installation and application)
   ✓ PASS - ArgoCD running (4 pods), fk-webstack-app configured

7. Logging (Optional - ELK/Loki stack)
   ⚠ WARN - Not implemented (optional feature)

======================================
Summary: 6/7 criteria passed
======================================
```

---

### Step 7: Test Application

#### Test API

**Terminal 1:**
```powershell
vagrant ssh fk-control -c "kubectl port-forward svc/fk-api -n fk-webstack 8000:8000"
```

**Terminal 2:**
```powershell
Invoke-RestMethod http://localhost:8000/api/name
```

**Expected Response:**
```json
{"name":"Frank Koch"}
```

#### Test MongoDB Integration

```powershell
Invoke-RestMethod http://localhost:8000/api/users
```

**Expected Response:**
```json
[
  {"name":"Frank Koch","email":"frank@example.com"},
  {"name":"John Doe","email":"john@example.com"}
]
```

#### Access Grafana

**Terminal 1:**
```powershell
vagrant ssh fk-control -c "kubectl port-forward svc/fk-monitoring-grafana -n monitoring 3000:80"
```

**Browser:**
- URL: http://localhost:3000
- Username: `admin`
- Password: `admin`

**What to Check:**
- Navigate to "Dashboards" → "Kubernetes / Compute Resources / Cluster"
- Verify CPU and memory usage graphs show data
- Check that all nodes appear in the dashboard

#### Access ArgoCD

**Terminal 1:**
```powershell
vagrant ssh fk-control -c "kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443"
```

**Get Password:**
```powershell
vagrant ssh fk-control -c "kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d"
```

**Browser:**
- URL: https://localhost:8080 (ignore SSL warning)
- Username: `admin`
- Password: (from command above)

**What to Check:**
- Click on "fk-webstack-app" application
- Verify it shows as "Synced" and "Healthy"
- View the resource tree showing MongoDB, API, Frontend

---

## Troubleshooting Common Issues

### Issue: Workers Stuck in "NotReady"

**Symptoms:**
```
fk-worker1   NotReady   <none>   5m   v1.35.0
```

**Solution:**
```powershell
# Check Flannel pods
vagrant ssh fk-control -c "kubectl get pods -n kube-flannel"

# If Flannel pods are CrashLoopBackOff, reload workers
vagrant reload fk-worker1
vagrant reload fk-worker2
```

---

### Issue: Prometheus Using Too Much Memory

**Symptoms:**
- Control plane becomes slow
- API server timeout errors
- kubectl commands hang

**Solution:**
```powershell
# Check memory usage
vagrant ssh fk-control -c "free -h"

# If memory is exhausted, reduce Prometheus retention
vagrant ssh fk-control -c "
  kubectl patch prometheus fk-monitoring-kube-prometheus-prometheus \
    -n monitoring \
    --type merge \
    -p '{\"spec\":{\"retention\":\"3h\"}}'
"
```

---

### Issue: Pods Stuck in "Terminating"

**Symptoms:**
```
NAMESPACE     NAME                      READY   STATUS
fk-webstack   fk-api-xxx-xxx            0/1     Terminating
```

**Solution:**
```powershell
vagrant ssh fk-control -c "bash /vagrant/cleanup-stuck-resources.sh"
```

---

### Issue: cert-manager Webhook Failing

**Symptoms:**
```
cert-manager-webhook-xxx   0/1   CrashLoopBackOff
```

**Solution:**
```powershell
# Delete the pod, it will restart
vagrant ssh fk-control -c "kubectl delete pod -n cert-manager -l app=webhook"

# Wait 30 seconds
Start-Sleep 30

# Check status
vagrant ssh fk-control -c "kubectl get pods -n cert-manager"
```

---

## Time Estimates

| Phase | Duration | What Happens |
|-------|----------|--------------|
| VM Destroy | 1-2 min | Cleanup existing VMs |
| Vagrant Up | 10-15 min | Start & provision all VMs |
| Build Images | 2-3 min | Build Docker images on each node |
| Deploy Stack | 5-8 min | Deploy all Kubernetes resources |
| Verification | 1 min | Run success criteria checks |
| **TOTAL** | **20-30 min** | Complete rebuild from scratch |

---

## Final Verification Checklist

- [ ] 3 nodes all showing "Ready" status
- [ ] MongoDB pod Running with 1/1 Ready
- [ ] API deployment shows 2-4 pods Running
- [ ] Frontend deployment shows 2 pods Running
- [ ] cert-manager namespace has 3 pods Running
- [ ] monitoring namespace has Prometheus and Grafana Running
- [ ] argocd namespace has 4+ pods Running
- [ ] API responds with `{"name":"Frank Koch"}`
- [ ] Grafana dashboard accessible at localhost:3000
- [ ] ArgoCD UI accessible at localhost:8080
- [ ] No pods stuck in CrashLoopBackOff or Error state

---

## Post-Deployment Maintenance

### Daily Operations

```powershell
# Check cluster health
vagrant ssh fk-control -c "kubectl get nodes"
vagrant ssh fk-control -c "kubectl get pods -A"

# View resource usage
vagrant ssh fk-control -c "kubectl top nodes"
vagrant ssh fk-control -c "kubectl top pods -A"
```

### Updating Application

```bash
# Make changes to code, rebuild images
vagrant ssh fk-control -c "bash /vagrant/vagrant/06-build-images.sh"

# Restart deployments to use new images
vagrant ssh fk-control -c "
  kubectl rollout restart deployment/fk-api -n fk-webstack
  kubectl rollout restart deployment/fk-frontend -n fk-webstack
"

# Watch rollout
vagrant ssh fk-control -c "kubectl rollout status deployment/fk-api -n fk-webstack"
```

### Backing Up Cluster State

```powershell
# Backup kubeconfig
vagrant ssh fk-control -c "cat /root/.kube/config" > cluster-kubeconfig.yaml

# Backup all manifests
vagrant ssh fk-control -c "kubectl get all -A -o yaml" > cluster-backup.yaml

# Backup MongoDB data (optional)
vagrant ssh fk-control -c "kubectl exec -n fk-webstack deployment/fk-mongodb -- mongodump --archive" > mongodb-backup.archive
```

---

## Success!

Your FK Webstack is now fully deployed and verified. All 7 success criteria should be met:

1. ✅ Docker Stack
2. ✅ Kubernetes Cluster  
3. ✅ Live Data (MongoDB)
4. ✅ TLS (cert-manager)
5. ✅ Monitoring (Prometheus/Grafana)
6. ✅ GitOps (ArgoCD)
7. ⚠️ Logging (optional, not implemented)

You're ready for your exam! 🎉
