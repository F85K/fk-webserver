# Manual Kubernetes Provisioning Guide

After `vagrant up` creates the bare VMs, follow these steps to manually provision and deploy your cluster.

---

## Step 1: Start Bare VMs (5-10 minutes)

```powershell
cd C:\Users\Admin\Desktop\WebserverLinux
vagrant up

# Wait for all 3 VMs to boot successfully
# You should see: "Bringing machine 'fk-worker2' up with 'virtualbox' provider... Done"
```

---

## Step 2: Provision Control Plane (10-15 minutes)

SSH into control plane and run provisioning scripts in order:

```powershell
vagrant ssh fk-control
```

Now inside the VM (`vagrant@fk-control:~$`):

```bash
# Step 2.1: Base system setup (installs Docker, updates packages)
bash /vagrant/vagrant/01-base-setup.sh

# Step 2.2: Install Kubernetes tools (kubeadm, kubelet, kubectl)
bash /vagrant/vagrant/02-kubeadm-install.sh

# Step 2.3: Initialize Kubernetes control plane
# This takes 5-10 minutes (etcd initialization is slow)
bash /vagrant/vagrant/03-control-plane-init.sh

# Verify control plane is ready
kubectl get nodes
# Expected: 1 node (fk-control) in Ready state

# Verify CNI (Flannel) is installed
kubectl get pods -n kube-flannel
# Expected: kube-flannel-ds pods should be Running
```

**If anything fails**, check logs:
```bash
# Check kubelet logs
sudo journalctl -u kubelet -n 50 --no-pager

# Check API server status
sudo systemctl status kube-apiserver || echo "Static pod - check kubelet logs"
```

---

## Step 3: Provision Worker Nodes (10 minutes each)

From **outside** (Windows PowerShell), provision each worker:

```powershell
# Worker 1
vagrant ssh fk-worker1 -c "bash /vagrant/vagrant/01-base-setup.sh && bash /vagrant/vagrant/02-kubeadm-install.sh && bash /vagrant/vagrant/04-worker-join.sh"

# Worker 2
vagrant ssh fk-worker2 -c "bash /vagrant/vagrant/01-base-setup.sh && bash /vagrant/vagrant/02-kubeadm-install.sh && bash /vagrant/vagrant/04-worker-join.sh"

# Wait ~3-5 minutes for workers to join and become Ready
```

**Verify workers joined:**

```powershell
# SSH back into control plane
vagrant ssh fk-control

# Check all nodes
kubectl get nodes

# Expected:
# NAME          STATUS   ROLES           AGE   VERSION
# fk-control    Ready    control-plane   5m    v1.28.x
# fk-worker1    Ready    <none>          2m    v1.28.x
# fk-worker2    Ready    <none>          2m    v1.28.x
```

**If workers stay NotReady for >2 minutes:**

```bash
# Check Flannel on workers
kubectl get pods -n kube-flannel -o wide

# Check worker join logs
vagrant ssh fk-worker1 -c "sudo journalctl -u kubelet -n 50 --no-pager"

# If stuck, restart worker kubelet
vagrant ssh fk-worker1 -c "sudo systemctl restart kubelet"
```

---

## Step 4: Build Docker Images (2 minutes)

Inside control plane:

```bash
# Go to project directory
cd /vagrant

# Build API image with FIXED MongoDB connection (lazy loading)
docker build -t fk-api:latest ./api

# Build frontend image
docker build -t fk-frontend:latest ./frontend

# Verify images built
docker images | grep fk-
```

**Expected output:**
```
REPOSITORY      TAG       IMAGE ID      CREATED       SIZE
fk-api          latest    abc123def456  39 seconds ago 450MB
fk-frontend     latest    def456ghi789  25 seconds ago 50MB
```

---

## Step 5: Load Images Into Containerd (1 minute)

Still inside control plane:

```bash
# Save images as tar files
docker save fk-api:latest -o /tmp/fk-api.tar
docker save fk-frontend:latest -o /tmp/fk-frontend.tar

# Import into containerd (Kubernetes uses containerd, not Docker)
sudo ctr -n k8s.io images import /tmp/fk-api.tar
sudo ctr -n k8s.io images import /tmp/fk-frontend.tar

# Verify images are loaded in Kubernetes
sudo crictl images | grep fk-

# Expected:
# fk-api    latest    <hash>    450MB
# fk-frontend latest    <hash>    50MB
```

---

## Step 6: Deploy Applications (10-15 minutes)

Still inside control plane:

```bash
# Run the comprehensive deployment script
bash /vagrant/vagrant/deploy-full-stack.sh

# This script:
# 1. Creates fk-webstack namespace
# 2. Deploys MongoDB with initialized data (Frank Koch)
# 3. Deploys FastAPI with fixed MongoDB connection
# 4. Deploys Lighttpd frontend
# 5. Installs cert-manager (TLS support)
# 6. Installs Prometheus/Grafana monitoring
# 7. Installs ArgoCD for GitOps

# Takes 10-15 minutes due to Helm chart downloads and pod initialization
```

**Monitor pods coming up:**

```bash
# In another terminal/tab inside the control plane:
kubectl get pods -n fk-webstack -w

# Press Ctrl+C when all pods show Running (after ~3 minutes)
```

---

## Step 7: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n fk-webstack -o wide

# Expected output:
# NAME                        READY   STATUS    RESTARTS   AGE
# fk-mongodb-xxxxx            1/1     Running   0          2m
# fk-api-xxxxx                1/1     Running   0          90s
# fk-frontend-xxxxx           1/1     Running   0          90s
# fk-mongo-init-job-xxxxx     0/1     Completed 0          2m

# Test API endpoints
kubectl port-forward svc/fk-api 8000:8000 -n fk-webstack &
sleep 2

curl http://localhost:8000/health
# Expected: {"status":"ok"}

curl http://localhost:8000/api/name
# Expected: {"name":"Frank Koch"}

# Stop port forward
jobs
kill %1
```

**Run success criteria check:**

```bash
bash /vagrant/vagrant/verify-success-criteria.sh

# Expected: 7/7 PASS (or at least 6/7 if ArgoCD had brief issues)
```

---

## Complete Timeline

| Step | Task | Time |
|------|------|------|
| 1 | `vagrant up` (bare VMs) | 5-10 min |
| 2 | Control Plane provisioning | 10-15 min |
| 3 | Worker provisioning (2 nodes) | 15-20 min |
| 4 | Build Docker images | 2 min |
| 5 | Load images to containerd | 1 min |
| 6 | Deploy full stack | 10-15 min |
| 7 | Verify deployment | 5 min |
| **TOTAL** | **Full cluster ready** | **50-70 min** |

---

## Troubleshooting Quick Reference

### API Pod Crashing (CrashLoopBackOff)

```bash
# Check logs
kubectl logs -n fk-webstack -l app=fk-api --tail=50

# Likely causes:
# 1. MongoDB not running yet (should recover automatically with lazy connection)
# 2. Image not loaded in containerd
# 3. Memory exhaustion on node

# Fix: Restart API deployment
kubectl rollout restart deployment/fk-api -n fk-webstack
```

### Workers NotReady After Join

```bash
# Check node status
kubectl describe node fk-worker1

# Check Flannel on that node
kubectl get pods -n kube-flannel -o wide

# Restart node kubelet
vagrant ssh fk-worker1 -c "sudo systemctl restart kubelet"

# Wait 30 seconds and recheck
sleep 30
kubectl get nodes
```

### Kubernetes API Server Not Responding

```bash
# From control plane, check API server
sudo systemctl status kube-apiserver || echo "Static pod - check kubelet"

# Check kubelet
sudo systemctl status kubelet

# Check for memory issues
free -h

# View recent errors
sudo journalctl -u kubelet -n 100 --no-pager | tail -50
```

### MongoDB Not Initializing Data

```bash
# Check init job
kubectl get jobs -n fk-webstack

# If failed, check job logs
kubectl logs -n fk-webstack job/fk-mongo-init-job

# Manually initialize MongoDB
kubectl exec -it $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh

# Inside mongosh:
use fkdb
db.profile.insertOne({key: "name", value: "Frank Koch"})
exit
```

---

## Accessing Services

### API (from control plane)
```bash
kubectl port-forward svc/fk-api 8000:8000 -n fk-webstack &
curl http://localhost:8000/api/name
```

### Frontend (from control plane)
```bash
kubectl port-forward svc/fk-frontend 8080:8080 -n fk-webstack &
# Browse to http://localhost:8080 from Windows
```

### Grafana Dashboard
```bash
kubectl port-forward svc/fk-monitoring-grafana 3000:80 -n monitoring &
# Browse to http://localhost:3000
# Login: admin / admin
```

### ArgoCD
```bash
ARGOCD_PASS=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)
echo "ArgoCD password: $ARGOCD_PASS"

kubectl port-forward svc/argo-cd-argocd-server 8080:443 -n argocd &
# Browse to https://localhost:8080
# Login: admin / $ARGOCD_PASS
```

---

## Next Steps After Deployment

1. **Verify all endpoints working** ✅
2. **Check monitoring dashboards** (Prometheus, Grafana)
3. **Review ArgoCD for GitOps setup**
4. **Test pod scaling** with HPA
5. **Document any additional issues** in `DEPLOYMENT-ISSUES-FOUND.md`

---

## Notes

- **Lazy MongoDB Connection**: API pod doesn't need MongoDB to be ready at startup
- **Kubernetes 1.28**: Stable, widely supported version
- **Resource Allocation**: 12GB total (6GB control + 3GB × 2 workers) is generous
- **All scripts idempotent**: Safe to run multiple times
- **Manual provisioning advantage**: Easy to debug and understand each component

Good luck! 🚀
