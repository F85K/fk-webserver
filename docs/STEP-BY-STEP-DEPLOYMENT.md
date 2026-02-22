# FK Webstack - Complete Step-by-Step Deployment Guide

This guide walks you through the complete deployment process, from PowerShell on Windows through Kubernetes cluster setup.

---

## Prerequisites

- **Windows Host**: PowerShell with Docker Desktop running
- **Vagrant**: Installed and configured
- **VirtualBox**: Installed with adequate resources (≥12GB RAM for VM cluster)
- **Git/GitHub**: (Optional) For cloning repository

---

## Phase 1: Initial Vagrant Setup (Windows PowerShell)

### Step 1.1: Navigate to Project Directory
```powershell
cd C:\Users\Admin\Desktop\WebserverLinux
```

### Step 1.2: Verify Prerequisites
```powershell
# Check Vagrant is installed
vagrant --version

# Check VirtualBox is running
vboxmanage --version

# Verify Docker Desktop is running (will help with image caching)
docker ps
```

### Step 1.3: Clean Previous Deployments (if re-deploying)
```powershell
# Remove old VMs if they exist
vagrant destroy -f

# Remove old container data
docker-compose down

# Clean up old images
docker rmi fk-api:latest fk-frontend:latest 2>$null
```

### Step 1.4: Start Control Plane ONLY
```powershell
# Start ONLY the control plane first
vagrant up fk-control

# This will take 8-15 minutes (depends on network speed)
# Watch for "vagrant up" to complete with exit code 0
```

**Expected Output:**
- Vagrant starts `fk-control` VM
- Runs: `01-base-setup.sh` → `02-kubeadm-install.sh` → `03-control-plane-init.sh`
- Control plane initialized, Flannel CNI installed
- Job completes with "fk-control: 0" (success)

### Step 1.5: Verify Control Plane Is Ready
```powershell
# SSH into control plane
vagrant ssh fk-control

# You should see the Vagrant prompt now
vagrant@fk-control:~$
```

---

## Phase 2: Prepare Control Plane (Inside VM)

Once you're SSH'd into `fk-control`, you're in the VM shell.

### Step 2.1: Check Kubernetes Control Plane Status
```bash
# Export kubeconfig (might already be set)
export KUBECONFIG=/root/.kube/config

# Verify kubectl works
kubectl get nodes

# Expected: Shows fk-control as Ready (might take 2-3 minutes)
```

**⚠️ CRITICAL**: If `kubectl get nodes` fails with "connection refused":
- The control plane is still initializing
- Wait 5 more minutes and retry
- Check: `systemctl status kubelet` to see if still starting

### Step 2.2: Verify Flannel is Installed
```bash
# Check Flannel pods
kubectl get pods -n kube-flannel

# Expected: kube-flannel-ds-xxxxx pods in Running state
```

**⚠️ If Flannel pods are stuck in CrashLoopBackOff**:
```bash
# Reinstall Flannel manually
kubectl delete ds/kube-flannel-ds -n kube-flannel 2>/dev/null || true
kubectl apply -f https://github.com/flannel-io/flannel/releases/download/v0.25.1/kube-flannel.yml

# Wait 30 seconds and recheck
sleep 30
kubectl get pods -n kube-flannel
```

### Step 2.3: Build Docker Images
```bash
# Navigate to project directory
cd /vagrant

# Build API image with FIXED MongoDB connection
docker build -t fk-api:latest ./api

# Build Frontend image
docker build -t fk-frontend:latest ./frontend

# Verify images built successfully
docker images | grep fk-

# Expected: Shows fk-api and fk-frontend with latest tag
```

### Step 2.4: Load Images Into Containerd
```bash
# Save images as tar files
docker save fk-api:latest -o /tmp/fk-api.tar
docker save fk-frontend:latest -o /tmp/fk-frontend.tar

# Import into containerd (Kubernetes uses containerd, not Docker)
sudo ctr -n k8s.io images import /tmp/fk-api.tar
sudo ctr -n k8s.io images import /tmp/fk-frontend.tar

# Verify images are loaded
sudo crictl images | grep fk-

# Expected: Shows fk-api and fk-frontend in system image store
```

### Step 2.5: Create Marker File for Workers
```bash
# Create .flannel-ready marker so workers know CNI is ready
mkdir -p /vagrant/kubeadm-config
touch /vagrant/kubeadm-config/.flannel-ready
touch /vagrant/kubeadm-config/.control-plane-ready

# Verify marker files exist
ls -la /vagrant/kubeadm-config/

# Expected: Shows .flannel-ready and .control-plane-ready files
```

### Step 2.6: Test Control Plane is Fully Ready
```bash
# Verify API server responds
kubectl get componentstatuses

# Expected: All components show Healthy

# Verify no node issues
kubectl get nodes -o wide

# Expected: All nodes (at least fk-control) are Ready
```

**⏸️ PAUSE HERE - Do NOT start workers until this passes!**

---

## Phase 3: Start Worker Nodes (From Windows PowerShell)

**Return to Windows PowerShell** (exit the SSH session with `exit` command or Ctrl+D)

### Step 3.1: Start Workers
```powershell
# Back in PowerShell, start both workers
vagrant up fk-worker1 fk-worker2

# This will take 10-15 minutes
# Workers will:
#   1. Start up
#   2. Wait for control plane marker files
#   3. Get join command from control plane
#   4. Join the cluster
#   5. Set up Flannel on worker nodes
```

**Expected Output:**
- Both workers start and initialize
- Should see "provisioning fk-worker1" and "provisioning fk-worker2"
- Each runs: `01-base-setup.sh` → `02-kubeadm-install.sh` → `04-worker-join.sh`
- Completes with both workers successfully joined

### Step 3.2: Monitor Worker Join Progress (Optional)
```powershell
# In a new PowerShell tab, monitor the workers
vagrant ssh fk-control -c "watch kubectl get nodes"

# Or manually check periodically
vagrant ssh fk-control -c "kubectl get nodes"

# Expected progression:
# - fk-worker1 appears as NotReady (CNI starting)
# - fk-worker2 appears as NotReady (CNI starting)
# - After ~2 minutes: both become Ready
```

---

## Phase 4: Deploy Applications (SSH to Control Plane)

### Step 4.1: SSH Back Into Control Plane
```powershell
vagrant ssh fk-control
```

### Step 4.2: Verify All Nodes Are Ready
```bash
kubectl get nodes

# Expected: All 3 nodes show "Ready" status
# If any show "NotReady" or "NotReady,SchedulingDisabled": wait 30 more seconds
```

**⚠️ If workers are NotReady for >2 minutes**:
```bash
# Check Flannel on workers
kubectl get pods -n kube-flannel

# All should be Running. If not:
kubectl describe pod <flannel-pod-name> -n kube-flannel

# Wait for Flannel to start (it requires network to be ready)
```

### Step 4.3: Deploy Core Application Stack
```bash
# Deploy the FK Webstack (MongoDB, API, Frontend)
bash /vagrant/vagrant/deploy-full-stack.sh

# This will take 8-12 minutes, progressively deploying:
# 1. Namespace and ConfigMaps
# 2. MongoDB (with init job to seed defaults)
# 3. API (with health checks)
# 4. Frontend (Lighttpd)
# 5. cert-manager (for TLS)
# 6. Prometheus/Grafana (monitoring)
# 7. ArgoCD (GitOps)
```

**What the script does:**
- Creates `fk-webstack` namespace
- Deploys MongoDB with persistent storage
- Deploys FastAPI with lazy MongoDB connection (FIXED version)
- Deploys Lighttpd frontend
- Installs cert-manager via Helm
- Installs Prometheus/Grafana monitoring stack
- Installs ArgoCD for GitOps

### Step 4.4: Verify Application Pods Are Running
```bash
# Check FK Webstack pods
kubectl get pods -n fk-webstack

# Expected output:
# fk-mongodb-xxxxx         1/1     Running
# fk-api-xxxxx             1/1     Running (should reach Running within 20-30 seconds)
# fk-frontend-xxxxx        1/1     Running
# fk-mongo-init-job-xxxxx  0/1     Completed (init job should complete quickly)

# If API is still in CrashLoopBackOff after 2 minutes:
kubectl logs -n fk-webstack deployment/fk-api

# Common issues and fixes below
```

### Step 4.5: Wait for All Pods to Be Ready
```bash
# Watch pods come up
kubectl get pods -n fk-webstack -w

# Press Ctrl+C when all show Running (after ~2-3 minutes)
```

---

## Phase 5: Verify Deployment (Still in Control Plane Shell)

### Step 5.1: Test API Endpoints
```bash
# Get API service port
kubectl get svc -n fk-webstack fk-api

# Port forward to test locally (from within VM)
kubectl port-forward svc/fk-api 8000:8000 -n fk-webstack &

# Wait 2 seconds for port forward to start
sleep 2

# Test health endpoint
curl http://localhost:8000/health

# Expected: {"status":"ok"}

# Test name endpoint (should read from MongoDB)
curl http://localhost:8000/api/name

# Expected: {"name":"Frank Koch"}

# Test container ID endpoint
curl http://localhost:8000/api/container-id

# Expected: {"container_id":"<pod-name>"}

# Stop port forward
jobs
kill %1  # (or kill the job number shown)
```

### Step 5.2: Test Frontend
```bash
# Access frontend
kubectl port-forward svc/fk-frontend 8080:8080 -n fk-webstack &
sleep 2

# From Windows host, open browser:
# http://localhost:8080

# Or from control plane:
curl http://localhost:8080

# Expected: HTML that loads "Frank Koch has reached milestone 2!"

# Kill port forward
jobs
kill %1
```

### Step 5.3: Verify MongoDB Data
```bash
# Access MongoDB directly
kubectl port-forward svc/fk-mongodb 27017:27017 -n fk-webstack &
sleep 2

# Or shell into MongoDB pod
kubectl exec -it $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh

# Inside mongosh:
use fkdb
db.profile.find()

# Expected output:
# { _id: ObjectId(...), key: "name", value: "Frank Koch" }

# Exit mongosh
exit
```

### Step 5.4: Run Official Success Verification
```bash
# Run the comprehensive success criteria check
bash /vagrant/vagrant/verify-success-criteria.sh

# This checks:
# ✓ All 3 nodes Ready (Kubernetes Cluster)
# ✓ MongoDB, API, Frontend pods Running (Docker Stack)
# ✓ MongoDB init job completed (Live Data)
# ✓ cert-manager installed (TLS/Secrets)
# ✓ Monitoring stack (Prometheus/Grafana)
# ✓ ArgoCD running (GitOps)
# ✓ All endpoints accessible (Integration)

# Expected: 7/7 PASS (or at least 6/7 if ArgoCD had issues)
```

---

## Phase 6: Optional - Access Monitoring Dashboards

### Grafana (Monitoring)
```bash
# From inside control plane
kubectl port-forward svc/fk-monitoring-grafana 3000:80 -n monitoring &

# From Windows browser:
# http://localhost:3000
# Login: admin / admin

# Once logged in, check Kubernetes dashboard
```

### ArgoCD (GitOps)
```bash
# Get initial admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d
echo ""

# Port forward to ArgoCD
kubectl port-forward svc/argo-cd-argocd-server 8080:443 -n argocd &

# From Windows browser:
# https://localhost:8080
# Login: admin / <password-from-above>

# Note: Will show self-signed cert warning (click "Advanced" → "Continue")
```

---

## Common Issues & Solutions

### Issue 1: API Pod Stays in CrashLoopBackOff

**Symptom**: `kubectl get pods -n fk-webstack` shows API pod restarting every few seconds

**Root Cause**: MongoDB not ready, or old code trying to connect at startup

**Fix**:
```bash
# Check logs
kubectl logs -n fk-webstack deployment/fk-api --tail=50

# Force restart API  
kubectl rollout restart deployment/fk-api -n fk-webstack

# If still fails, the image might be old - rebuild:
# (from Windows or after exiting)
exit  # Exit control plane
vagrant ssh fk-control -c "cd /vagrant && docker build -t fk-api:latest ./api && docker save fk-api:latest -o /tmp/fk-api.tar && sudo ctr -n k8s.io images import /tmp/fk-api.tar"

# Then restart API:
vagrant ssh fk-control -c "kubectl rollout restart deployment/fk-api -n fk-webstack"
```

### Issue 2: Workers Won't Join (NotReady Status)

**Symptom**: Workers appear in `kubectl get nodes` but stay in NotReady state

**Root Cause**: Flannel not loaded, or kubelet waiting for CNI

**Fix**:
```bash
# Check Flannel pods
kubectl get pods -n kube-flannel

# Restart kubelet on worker
vagrant ssh fk-worker1 -c "sudo systemctl restart kubelet"
vagrant ssh fk-worker2 -c "sudo systemctl restart kubelet"

# Wait 30 seconds and check status
sleep 30
kubectl get nodes

# If still NotReady, check worker logs:
vagrant ssh fk-worker1 -c "sudo journalctl -xe -u kubelet | tail -50"
```

### Issue 3: cert-manager Timeout During Deploy

**Symptom**: `helm install cert-manager` hangs for >5 minutes

**Root Cause**: Control plane too busy with other pods

**Fix**:
```bash
# Cancel the script (Ctrl+C)
# Wait 3 minutes for control plane to stabilize
sleep 180

# Try installing cert-manager manually
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --timeout=5m

# Continue with rest of deployment:
kubectl apply -f /vagrant/k8s/51-selfsigned-issuer.yaml
```

### Issue 4: Kubernetes API Server Connection Refused

**Symptom**: `kubectl get nodes` shows "connection refused - did you specify the right host or port?"

**Root Cause**: API server crashed or not fully initialized

**Fix**:
```bash
# Check kubelet status
sudo systemctl status kubelet

# Check logs
sudo journalctl -xe -u kubelet | tail -100

# Restart kubelet
sudo systemctl restart kubelet

# Wait 2 minutes for recovery
sleep 120
kubectl get nodes

# If still failing, this is a critical etcd/API server issue
# May need to: vagrant destroy && vagrant up (full rebuild)
```

### Issue 5: Load Images Fail - "no match for platform"

**Symptom**: `sudo ctr -n k8s.io images import` fails with platform error

**Root Cause**: Image built on different architecture (rare on Windows)

**Fix**:
```bash
# Rebuild images with explicit platform
docker build --platform linux/amd64 -t fk-api:latest ./api
docker build --platform linux/amd64 -t fk-frontend:latest ./frontend

# Then reimport:
docker save fk-api:latest -o /tmp/fk-api.tar
sudo ctr -n k8s.io images import /tmp/fk-api.tar
```

---

## Complete Command Sequence (Quick Reference)

Use this if you want to run everything in sequence:

```powershell
# === WINDOWS POWERSHELL ===
cd C:\Users\Admin\Desktop\WebserverLinux

# Clean up old deployment
vagrant destroy -f
docker-compose down

# Start control plane (step 1-2)
vagrant up fk-control
# Wait 15 minutes...

# Build images inside control plane (or can skip and deploy-full-stack does this)
vagrant ssh fk-control -c "cd /vagrant && bash vagrant/06-build-images.sh"

# Start workers (step 3)
vagrant up fk-worker1 fk-worker2
# Wait 15 minutes...

# === INSIDE fk-control VM ===
vagrant ssh fk-control

# Deploy everything (step 4)
bash /vagrant/vagrant/deploy-full-stack.sh
# Wait 10-12 minutes...

# Verify deployment (step 5)
bash /vagrant/vagrant/verify-success-criteria.sh

# Test endpoints
kubectl port-forward svc/fk-api 8000:8000 -n fk-webstack &
curl http://localhost:8000/api/name
jobs; kill %1

# === Done! ===
```

---

## Testing Checklist

- [ ] Control plane initializes and `kubectl get nodes` shows 1 Ready node
- [ ] Flannel pods are Running in kube-flannel namespace
- [ ] Workers start and automatically join cluster
- [ ] All 3 nodes show Ready after ~2 minutes
- [ ] MongoDB pod is Running
- [ ] API pod is Running (not CrashLoopBackOff)
- [ ] Frontend pod is Running
- [ ] MongoDB init job is Completed
- [ ] `curl http://localhost:8000/health` returns `{"status":"ok"}`
- [ ] `curl http://localhost:8000/api/name` returns `{"name":"Frank Koch"}`
- [ ] Frontend HTML loads in browser
- [ ] `verify-success-criteria.sh` shows 7/7 PASS

---

## Notes

- **Control plane takes 8-15 min** because etcd initialization is slow on limited hardware
- **Worker join takes 10 min** because they wait for control plane startup
- **API is fixed** to not crash waiting for MongoDB (implements lazy connection)
- **All scripts have built-in retries** and wait times for stability
- **If something fails, check logs** before restarting:
  ```bash
  kubectl logs -n NAMESPACE POD_NAME
  kubectl describe pod POD_NAME -n NAMESPACE
  journalctl -xe -u kubelet  # For node-level issues
  ```

---

## Cleanup

To destroy everything and start over:

```powershell
# From Windows:
vagrant destroy -f
docker-compose down
docker rmi fk-api:latest fk-frontend:latest
```

Good luck! 🚀
