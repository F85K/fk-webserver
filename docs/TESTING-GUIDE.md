# FK Webstack - Testing & Access Guide
**Created:** February 1, 2026  
**Project:** Kubernetes Cluster (kubeadm) with 3-Tier Web Application

---

## 🚀 Quick Start - Testing Everything

### Step 1: Verify Cluster is Ready
```powershell
# Check all nodes are Ready
vagrant ssh fk-control -c "kubectl get nodes"

# Expected output:
# NAME           STATUS   ROLES           AGE   VERSION
# fk-control     Ready    control-plane   Xh    v1.35.0
# fk-worker2     Ready    <none>          Xh    v1.35.0
# ubuntu-jammy   Ready    <none>          Xh    v1.35.0
```

### Step 2: Check FK Webstack Pods
```powershell
vagrant ssh fk-control -c "kubectl get pods -n fk-webstack"

# Expected: All pods Running (1/1)
```

---

## 🌐 Accessing the Frontend

### Option 1: Port-Forward (Recommended for Testing)
```powershell
# In PowerShell terminal 1:
vagrant ssh fk-control -c "kubectl port-forward -n fk-webstack svc/fk-frontend 8080:80"

# In PowerShell terminal 2 or browser:
Start-Process "http://localhost:8080"
```

**Expected Result:**
- Page shows: **"Frank Koch has reached milestone 2!"**
- Name fetched dynamically from MongoDB via API
- Container ID displayed (shows load balancing)

### Option 2: NodePort (Alternative)
```powershell
# Change service type to NodePort
vagrant ssh fk-control -c "kubectl patch svc fk-frontend -n fk-webstack -p '{\"spec\":{\"type\":\"NodePort\"}}'"

# Get the NodePort
vagrant ssh fk-control -c "kubectl get svc fk-frontend -n fk-webstack"
# Look for port like 30XXX in PORT(S) column: 80:30XXX/TCP

# Access in browser (replace 30XXX with actual port)
Start-Process "http://192.168.56.10:30XXX"
```

---

## 🔌 Testing API Endpoints

### From Windows Host (via Port-Forward)
```powershell
# Terminal 1: Forward API service
vagrant ssh fk-control -c "kubectl port-forward -n fk-webstack svc/fk-api 8000:8000"

# Terminal 2: Test endpoints
Invoke-RestMethod -Uri "http://localhost:8000/api/name"
# Expected: {"name":"Frank Koch"}

Invoke-RestMethod -Uri "http://localhost:8000/api/container-id"
# Expected: {"container_id":"fk-api-xxx-yyy"}

Invoke-RestMethod -Uri "http://localhost:8000/health"
# Expected: {"status":"ok"}
```

### From Inside Cluster (Recommended)
```powershell
# Test API from temporary pod
vagrant ssh fk-control -c "kubectl run test --image=curlimages/curl:latest --rm -it --restart=Never -- curl http://fk-api.fk-webstack:8000/api/name"

# Expected output:
# {"name":"Frank Koch"}
# pod "test" deleted
```

---

## 🗄️ Changing Name in MongoDB

### Method 1: Using MongoDB Shell (mongosh)
```powershell
# Connect to MongoDB pod
vagrant ssh fk-control -c "kubectl exec -it deploy/fk-mongodb -n fk-webstack -- mongosh frankdb"

# Inside mongosh shell:
db.profile.updateOne({key: "name"}, {$set: {value: "Your New Name"}})
exit

# Verify change
vagrant ssh fk-control -c "kubectl run test --image=curlimages/curl:latest --rm -it --restart=Never -- curl http://fk-api.fk-webstack:8000/api/name"
```

### Method 2: One-Line Command
```powershell
vagrant ssh fk-control -c "kubectl exec deploy/fk-mongodb -n fk-webstack -- mongosh frankdb --eval 'db.profile.updateOne({key: \"name\"}, {\$set: {value: \"New Name\"}})'"
```

### Method 3: Re-run Init Job
```bash
# Edit ConfigMap with new name
vagrant ssh fk-control -c "kubectl edit configmap fk-mongo-init -n fk-webstack"

# Change line: {$set: {value: "Frank Koch"}} 
# to: {$set: {value: "Your Name"}}

# Delete and recreate job
vagrant ssh fk-control -c "kubectl delete job fk-mongo-init-job -n fk-webstack"
vagrant ssh fk-control -c "kubectl apply -f /vagrant/k8s/13-mongodb-init-job.yaml"
```

---

## 🏥 Testing Healthchecks

### View Current Health Status
```powershell
vagrant ssh fk-control -c "kubectl describe pod -l app=fk-api -n fk-webstack | Select-String -Pattern 'Liveness|Readiness'"
```

### Test Liveness Probe (Restart on Failure)
```powershell
# Get API pod name
vagrant ssh fk-control -c "kubectl get pods -n fk-webstack -l app=fk-api"

# Kill the API process (pod will restart)
vagrant ssh fk-control -c "kubectl exec -it fk-api-xxx-yyy -n fk-webstack -- pkill python"

# Watch pod restart
vagrant ssh fk-control -c "kubectl get pods -n fk-webstack -l app=fk-api --watch"

# Expected behavior:
# 1. Pod goes from Running → NotReady
# 2. After 3 failed liveness checks (30s), pod restarts
# 3. Pod returns to Running state
```

### Manual Health Check
```powershell
vagrant ssh fk-control -c "kubectl run test --image=curlimages/curl:latest --rm -it --restart=Never -- curl http://fk-api.fk-webstack:8000/health"

# Expected: {"status":"ok"}
```

---

## 📈 Testing Horizontal Pod Autoscaler (HPA)

### View Current HPA Status
```powershell
vagrant ssh fk-control -c "kubectl get hpa -n fk-webstack"

# Expected:
# NAME          REFERENCE          TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
# fk-api-hpa    Deployment/fk-api  <unknown>/50%   2         4         2          Xh
```

### Generate Load to Trigger Scaling
```powershell
# Start load generator
vagrant ssh fk-control -c "kubectl run load-generator --image=busybox:1.28 --restart=Never -n fk-webstack -- /bin/sh -c 'while sleep 0.01; do wget -q -O- http://fk-api.fk-webstack:8000/api/name; done'"

# Watch HPA scale up (wait 2-3 minutes)
vagrant ssh fk-control -c "kubectl get hpa -n fk-webstack --watch"

# Watch pods scale up
vagrant ssh fk-control -c "kubectl get pods -n fk-webstack -l app=fk-api --watch"

# Expected behavior:
# 1. CPU usage increases above 50%
# 2. HPA scales from 2 → 3 → 4 replicas
# 3. Pods distributed across fk-worker1 and fk-worker2

# Stop load
vagrant ssh fk-control -c "kubectl delete pod load-generator -n fk-webstack"

# Watch scale down (wait 5 minutes)
# Expected: 4 → 3 → 2 replicas
```

---

## 🔐 HTTPS / TLS Testing

**Note:** cert-manager and Ingress require additional deployment. Basic stack uses ClusterIP services.

### Check if cert-manager is Installed
```powershell
vagrant ssh fk-control -c "kubectl get pods -n cert-manager"

# If not found, install:
vagrant ssh fk-control -c "kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml"
```

### Deploy Certificate Issuers
```powershell
vagrant ssh fk-control -c "kubectl apply -f /vagrant/k8s/51-selfsigned-issuer.yaml"
```

### Check Certificate Status
```powershell
vagrant ssh fk-control -c "kubectl get certificate -n fk-webstack"
vagrant ssh fk-control -c "kubectl get clusterissuer"
```

---

## 📊 Monitoring with Prometheus (Optional)

### Install Prometheus Stack
```powershell
# Add Helm repo
vagrant ssh fk-control -c "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
vagrant ssh fk-control -c "helm repo add prometheus-community https://prometheus-community.github.io/helm-charts"
vagrant ssh fk-control -c "helm repo update"

# Install kube-prometheus-stack
vagrant ssh fk-control -c "helm install fk-monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace"

# Wait for pods to be ready (5-10 minutes)
vagrant ssh fk-control -c "kubectl get pods -n monitoring --watch"
```

### Access Grafana Dashboard
```powershell
# Terminal 1: Port-forward Grafana
vagrant ssh fk-control -c "kubectl port-forward -n monitoring svc/fk-monitoring-grafana 3000:80"

# Terminal 2: Open browser
Start-Process "http://localhost:3000"

# Default credentials:
# Username: admin
# Password: prom-operator
```

**Useful Dashboards:**
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace (Pods) - Select "fk-webstack"
- Node Exporter / Nodes

---

## 🔄 ArgoCD GitOps Deployment (Optional)

### Install ArgoCD
```powershell
vagrant ssh fk-control -c "kubectl create namespace argocd"
vagrant ssh fk-control -c "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

# Wait for pods
vagrant ssh fk-control -c "kubectl get pods -n argocd --watch"
```

### Access ArgoCD UI
```powershell
# Get admin password
vagrant ssh fk-control -c "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"

# Port-forward UI
vagrant ssh fk-control -c "kubectl port-forward -n argocd svc/argocd-server 8080:443"

# Open browser
Start-Process "https://localhost:8080"

# Login:
# Username: admin
# Password: <from command above>
```

### Deploy FK Stack via ArgoCD
```powershell
vagrant ssh fk-control -c "kubectl apply -f /vagrant/k8s/60-argocd-application.yaml"

# Check sync status
vagrant ssh fk-control -c "kubectl get application -n argocd"
```

---

## 🛠️ Troubleshooting Commands

### Check Pod Logs
```powershell
# MongoDB logs
vagrant ssh fk-control -c "kubectl logs deploy/fk-mongodb -n fk-webstack"

# API logs
vagrant ssh fk-control -c "kubectl logs deploy/fk-api -n fk-webstack"

# Frontend logs
vagrant ssh fk-control -c "kubectl logs deploy/fk-frontend -n fk-webstack"

# Init job logs
vagrant ssh fk-control -c "kubectl logs job/fk-mongo-init-job -n fk-webstack"
```

### Check Pod Events
```powershell
vagrant ssh fk-control -c "kubectl describe pod <pod-name> -n fk-webstack"
```

### Check Service Endpoints
```powershell
vagrant ssh fk-control -c "kubectl get endpoints -n fk-webstack"
```

### Check Resource Usage
```powershell
vagrant ssh fk-control -c "kubectl top nodes"
vagrant ssh fk-control -c "kubectl top pods -n fk-webstack"
```

### Restart All Pods
```powershell
vagrant ssh fk-control -c "kubectl rollout restart deployment -n fk-webstack"
```

### Delete and Recreate Everything
```powershell
# Delete namespace (removes all resources)
vagrant ssh fk-control -c "kubectl delete namespace fk-webstack"

# Recreate
vagrant ssh fk-control -c "kubectl apply -f /vagrant/k8s/"
```

---

## 🌐 Pod Distribution Across Nodes

### Check Where Pods are Running
```powershell
vagrant ssh fk-control -c "kubectl get pods -n fk-webstack -o wide"

# Look at NODE column:
# - ubuntu-jammy = fk-worker1 (192.168.56.11)
# - fk-worker2 (192.168.56.12)
```

### Force Pod to Specific Node (if needed)
```yaml
# Add to deployment YAML:
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/hostname: fk-worker2
```

---

## 📋 Complete Test Checklist for Oral Exam

- [ ] **Cluster:** 3 nodes Ready (1 control + 2 workers)
- [ ] **Pods:** All Running in fk-webstack namespace
- [ ] **Frontend:** Accessible via port-forward, shows "Frank Koch"
- [ ] **API:** `/api/name` returns correct JSON
- [ ] **API:** `/api/container-id` shows pod hostname
- [ ] **API:** `/health` returns `{"status":"ok"}`
- [ ] **MongoDB:** Can change name and see update on frontend
- [ ] **Healthcheck:** Kill API process → pod restarts automatically
- [ ] **HPA:** Load test causes scale from 2 → 4 replicas
- [ ] **Distribution:** Pods spread across worker1 and worker2
- [ ] **cert-manager:** (Optional) Certificate created
- [ ] **Prometheus:** (Optional) Grafana dashboards accessible
- [ ] **ArgoCD:** (Optional) FK application synced from GitHub

---

## 🎯 Demo Flow for Presentation

1. **Show Cluster** (2 min)
   ```powershell
   vagrant ssh fk-control -c "kubectl get nodes -o wide"
   vagrant ssh fk-control -c "kubectl get all -n fk-webstack"
   vagrant ssh fk-control -c "kubectl get pods -n fk-webstack -o wide"
   ```

2. **Access Frontend** (2 min)
   - Port-forward and open browser
   - Show name displayed
   - Show container ID (load balancing)

3. **Test API** (2 min)
   ```powershell
   # Test from inside cluster
   vagrant ssh fk-control -c "kubectl run test --image=curlimages/curl:latest --rm -it --restart=Never -- curl http://fk-api.fk-webstack:8000/api/name"
   ```

4. **Change MongoDB Name** (2 min)
   - Execute mongosh command
   - Refresh frontend → see new name

5. **Demo Healthcheck** (3 min)
   - Kill API process
   - Watch pod restart

6. **Demo HPA** (5 min - can be pre-recorded)
   - Start load generator
   - Show scaling 2 → 4 replicas
   - Show pods on different nodes

---

**Total Demo Time:** ~15 minutes  
**Backup:** Screenshots if live demo fails

Good luck! 🍀
