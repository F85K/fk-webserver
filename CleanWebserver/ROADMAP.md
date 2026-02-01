# ROADMAP - Step by Step Setup Guide

**Project:** FK Webstack (Frank Koch)  
**Status:** Complete Setup from Scratch  
**Estimated Time:** 45-60 minutes total

---

## Phase 1: Docker Containers (15 minutes) - LOCAL TESTING

**⚠️ IMPORTANT:** These images are for LOCAL testing only with docker-compose. 
When we move to Kubernetes on VMs (Phase 3), we'll rebuild these images INSIDE the VMs because Kubernetes needs them in the cluster's containerd, not Docker Desktop.

### Step 1.1: Build API Image

**File:** `containers/api/Dockerfile`

```bash
# Navigate to project
cd CleanWebserver

# Build FastAPI image
docker build -t fk-api:1.0 ./containers/api

# Verify
docker images | grep fk-api
# Should show: fk-api  1.0  [IMAGE_ID]  [SIZE]
```

**What it does:**
- Starts from Python 3.11 slim base
- Installs FastAPI, uvicorn, pymongo dependencies
- Copies application code
- Exposes port 8000
- Runs: `uvicorn app.main:app --host 0.0.0.0 --port 8000`

### Step 1.2: Build Frontend Image

**File:** `containers/frontend/Dockerfile`

```bash
# Build lighttpd image
docker build -t fk-frontend:1.0 ./containers/frontend

# Verify
docker images | grep fk-frontend
# Should show: fk-frontend  1.0  [IMAGE_ID]  [SIZE]
```

**What it does:**
- Starts from Debian bookworm-slim
- Installs lighttpd web server
- Copies lighttpd.conf (configuration)
- Copies index.html (web page)
- Exposes port 80
- Runs: `lighttpd -D -f /etc/lighttpd/lighttpd.conf`

### Step 1.3: Pull MongoDB Image

```bash
# Pull MongoDB 6 (we use official image, don't build custom)
docker pull mongo:6

# Verify
docker images | grep mongo
# Should show: mongo  6  [IMAGE_ID]  [SIZE]
```

### Step 1.4: Test Locally with Docker Compose

**File:** `docker-compose.yaml`

```bash
# Start all 3 containers locally
docker-compose up -d

# Verify all running
docker-compose ps
# Should show 3 containers: fk-api, fk-frontend, fk-mongodb

# Test Frontend
curl http://localhost:8080
# Should show HTML page

# Test API
curl http://localhost:8000/api/name
# Should show: {"name":"Frank Koch"}

# Cleanup (optional, for now keep running)
# docker-compose down
```

**Why we do this:**
✅ Verifies images work correctly before Kubernetes  
✅ Tests API can talk to MongoDB  
✅ Confirms frontend loads  

---

## Phase 2: Vagrant Cluster Setup (20 minutes) - KUBEADM

### Step 2.1: Start VMs

**File:** `Vagrantfile`

```bash
# Navigate to project
cd CleanWebserver

# Create and provision 3 VMs (1 control + 2 workers)
# This will:
# - Download Ubuntu 22.04 image (~2GB, one-time)
# - Create 3 VMs with 2GB RAM each
# - Run provisioning scripts (Docker, kubeadm, cluster init)
# Total time: 15-20 minutes for first run
vagrant up

# During this time, you'll see:
# - fk-control: Booting → provisioning
# - fk-worker1: Booting → provisioning
# - fk-worker2: Booting → provisioning
```

### Step 2.2: Verify Cluster Ready

```bash
# SSH into control plane
vagrant ssh fk-control

# Inside VM, check nodes
kubectl get nodes
# Expected output (all Ready):
# NAME         STATUS   ROLES           AGE   VERSION
# fk-control   Ready    control-plane   2m    v1.35.0
# fk-worker1   Ready    <none>          1m    v1.35.0
# fk-worker2   Ready    <none>          1m    v1.35.0

# Check system pods
kubectl get pods -n kube-system
# Should see: coredns, flannel, kube-proxy running

# Exit SSH
exit
```

**What Vagrant provisioning does:**

1. **01-base-setup.sh**
   - Installs Docker 28.2.2
   - Installs containerd 1.7.28
   - Configures networking (iptables, ip_forward)
   - Disables swap (required by Kubernetes)

2. **02-kubeadm-install.sh**
   - Installs kubeadm, kubelet, kubectl v1.35.0
   - Holds packages to prevent auto-update

3. **03-control-plane-init.sh** (runs on fk-control only)
   - Initializes cluster: `kubeadm init --pod-network-cidr=10.244.0.0/16`
   - Installs Flannel CNI (networking)
   - Saves join token for workers
   - Creates KUBECONFIG

4. **04-worker-join.sh** (runs on both workers)
   - Retrieves join token from control plane
   - Runs: `kubeadm join ...`
   - Joins cluster as worker nodes

---

## Phase 3: Load Docker Images (5 minutes)

### Step 3.1: Build Images Inside VMs (MUST BE DONE INSIDE CLUSTER)

**⚠️ CRITICAL:** The images you built in Phase 1 on Windows are in Docker Desktop, but Kubernetes runs containerd inside the VMs. They can't see Windows Docker Desktop!

**Solution:** Rebuild images INSIDE each VM. The source code is available at `/vagrant/containers/` inside each VM.

```bash
# SSH into control plane
vagrant ssh fk-control

# Inside control VM, build API image
cd /vagrant/containers/api
docker build -t fk-api:1.0 .
# Output: Successfully tagged fk-api:1.0

# Build frontend  
cd /vagrant/containers/frontend
docker build -t fk-frontend:1.0 .
# Output: Successfully tagged fk-frontend:1.0

# Verify images are now in containerd (this is what Kubernetes sees)
sudo crictl images | grep fk-
# Should show:
# fk-api        1.0       [IMAGE_ID]  [SIZE]
# fk-frontend   1.0       [IMAGE_ID]  [SIZE]

# Exit control plane
exit
```

**Repeat for worker 1:**

```bash
vagrant ssh fk-worker1

# Build both images
docker build -t fk-api:1.0 /vagrant/containers/api
docker build -t fk-frontend:1.0 /vagrant/containers/frontend

# Verify
sudo crictl images | grep fk-

exit
```

**Repeat for worker 2:**

```bash
vagrant ssh fk-worker2

# Build both images
docker build -t fk-api:1.0 /vagrant/containers/api
docker build -t fk-frontend:1.0 /vagrant/containers/frontend

# Verify
sudo crictl images | grep fk-

exit
```

**Why build on all 3 nodes?**
- Kubernetes can schedule API pods on any node (control plane or workers)
- Pulling images across network is slow, so Kubernetes prefers local images
- With images on all nodes, deployment is fast and reliable

---

## Phase 4: Deploy Application (10 minutes)

### Step 4.1: Deploy Everything with Single Manifest

```bash
vagrant ssh fk-control

# Apply SINGLE file with all resources (namespace, configs, deployments, services, HPA)
kubectl apply -f /vagrant/kubernetes/manifests.yaml
# Output:
# namespace/fk-webstack created
# configmap/fk-mongo-init created
# deployment.apps/fk-mongodb created
# service/fk-mongodb created
# deployment.apps/fk-api created
# service/fk-api created
# horizontalpodautoscaler.autoscaling/fk-api-hpa created
# deployment.apps/fk-frontend created
# service/fk-frontend created

# Wait for all pods to start (30 seconds)
sleep 30

# Check all pods running
kubectl get pods -n fk-webstack
# Expected output:
# NAME                           READY   STATUS    RESTARTS   AGE
# fk-mongodb-xxxxx               1/1     Running   0          30s
# fk-api-xxxxx                   1/1     Running   0          25s
# fk-api-xxxxx                   1/1     Running   0          25s  (2nd replica)
# fk-frontend-xxxxx              1/1     Running   0          20s
```

### Step 4.2: Verify Namespace & Services Created

```bash
# Check namespace
kubectl get namespaces | grep fk-webstack
# Output: fk-webstack  Active

# Check ConfigMap (MongoDB init data)
kubectl get configmap -n fk-webstack
# Output: fk-mongo-init

# Check services
kubectl get svc -n fk-webstack
# Output:
# NAME           TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)
# fk-mongodb     ClusterIP   10.x.x.x       <none>        27017/TCP
# fk-api         ClusterIP   10.x.x.x       <none>        8000/TCP
# fk-frontend    ClusterIP   10.x.x.x       <none>        80/TCP
```

### Step 4.3: Verify HPA (Auto-scaling)

```bash
# Check Horizontal Pod Autoscaler
kubectl get hpa -n fk-webstack
# Output:
# NAME           REFERENCE           TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
# fk-api-hpa     Deployment/fk-api   0%/50%     2         4         2          30s

# This will auto-scale API between 2-4 replicas based on 50% CPU usage
exit
```

**What the manifests.yaml file contains:**

1. **Namespace** - `fk-webstack` (isolated environment for all resources)
2. **ConfigMap** - MongoDB init script with profile data
3. **MongoDB Deployment** - 1 replica, 512Mi memory, liveness/readiness probes
4. **MongoDB Service** - ClusterIP for API to connect
5. **API Deployment** - 2 replicas, FastAPI service, probes
6. **API Service** - ClusterIP for frontend to connect
7. **HPA** - Auto-scales API 2-4 replicas at 50% CPU
8. **Frontend Deployment** - 1 replica, lighttpd web server
9. **Frontend Service** - ClusterIP for port-forwarding

---

## Phase 5: Testing Application (5 minutes)

### Step 5.1: Access Frontend

```bash
vagrant ssh fk-control

# Port-forward frontend to localhost
kubectl port-forward -n fk-webstack svc/fk-frontend 8080:80

# In new PowerShell window
Start-Process "http://localhost:8080"

# Should see:
# - "Frank Koch has reached milestone 2!"
# - Container ID displayed
# - Refreshes every 5 seconds automatically
```

### Step 5.2: Test API Endpoints

```bash
# From outside cluster (on Windows PowerShell)
vagrant ssh fk-control -c "kubectl port-forward -n fk-webstack svc/fk-api 8000:8000"

# In new PowerShell window
curl http://localhost:8000/api/name
# Output: {"name":"Frank Koch"}

curl http://localhost:8000/api/container-id
# Output: {"container_id":"fk-api-xxx-yyy"}

curl http://localhost:8000/health
# Output: {"status":"ok"}
```

### Step 5.3: Test Database Changes

```bash
# Get MongoDB pod
kubectl get pods -n fk-webstack -l app=fk-mongodb

# Connect to MongoDB and change name
kubectl exec -it fk-mongodb-xxx -n fk-webstack -- mongosh

# Inside mongosh
use fkdb
db.profile.updateOne({}, {$set: {name: "Frank Koch v2"}})
exit

# Refresh frontend (browser)
# Name should now show "Frank Koch v2"

# Change back
kubectl exec -it fk-mongodb-xxx -n fk-webstack -- mongosh
use fkdb
db.profile.updateOne({}, {$set: {name: "Frank Koch"}})
exit
```

---

## Phase 6: Advanced Features (Optional - +2 to +4 points each)

### Step 6.1: HPA Autoscaling Demo (Verify Existing Feature)

```bash
vagrant ssh fk-control

# Watch HPA status
kubectl get hpa -n fk-webstack --watch

# In another terminal, generate load to trigger scaling
kubectl run -n fk-webstack load-generator --image=busybox:1.28 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://fk-api:8000/api/name; done"

# Watch replicas scale up (takes ~1-2 minutes)
# Output should show: 2 → 3 → 4 replicas as CPU increases above 50%

# Check current replicas
kubectl get deployment -n fk-webstack fk-api

# Stop load generator (Ctrl+C in load terminal, or from new terminal)
kubectl delete pod -n fk-webstack load-generator

# Replicas will scale back down to 2 (takes ~5 minutes)
```

---

### Step 6.2: Install cert-manager (HTTPS/TLS) - OPTIONAL +2 Points

**⚠️ COMPLETELY OFFLINE** - No GitHub, no DNS changes needed!

```bash
vagrant ssh fk-control

# Step 1: Install cert-manager from official release
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml

# Wait for cert-manager to be ready (~30 seconds)
echo "Waiting for cert-manager pods..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=300s 2>/dev/null || sleep 30

# Verify installation
kubectl get pods -n cert-manager
# Should see: cert-manager, cert-manager-webhook, cert-manager-cainjector all Running

# Step 2: Create self-signed ClusterIssuer (generates certificates locally inside cluster)
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: fk-selfsigned
spec:
  selfSigned: {}
EOF

# Step 3: Create Certificate (generates TLS cert signed by ClusterIssuer)
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: fk-webstack-cert
  namespace: fk-webstack
spec:
  secretName: fk-webstack-tls              # Secret name for K8s to use
  duration: 2160h                          # 90 days
  renewBefore: 720h                        # Renew 30 days before expiry
  commonName: fk-webstack.local
  isCA: false
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
  usages:
    - digital signature
    - key encipherment
  issuerRef:
    name: fk-selfsigned
    kind: ClusterIssuer
EOF

# Step 4: Verify certificate created (wait ~30 seconds)
sleep 30
kubectl get certificate -n fk-webstack
# Output example:
# NAME                   READY   SECRET              AGE
# fk-webstack-cert       True    fk-webstack-tls    15s

# View certificate details
kubectl describe certificate fk-webstack-cert -n fk-webstack

# Step 5: Verify TLS secret created
kubectl get secret -n fk-webstack fk-webstack-tls
# Shows: fk-webstack-tls   kubernetes.io/tls   2      30s

# (Optional) View certificate content
kubectl get secret -n fk-webstack fk-webstack-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

exit
```

**What cert-manager does:**
- ✅ Installs certificate management inside cluster
- ✅ Creates self-signed certificates automatically
- ✅ Stores certificates as Kubernetes secrets
- ✅ Can be used with Ingress for HTTPS (optional next step)

**No online signup required!** Everything is self-signed and local.

---

### Step 6.3: Install Prometheus (Monitoring) - OPTIONAL +2 Points

```bash
vagrant ssh fk-control

# Step 1: Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Step 2: Install Prometheus + Grafana stack
echo "Installing Prometheus (this takes ~2-3 minutes)..."
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.requests.cpu=100m \
  --set grafana.adminPassword=admin123

# Step 3: Wait for all Prometheus pods to be ready
echo "Waiting for Prometheus pods to start..."
sleep 30

kubectl get pods -n monitoring
# Should see: prometheus-operator, prometheus-prometheus-xxx, grafana-xxx all Running

# Step 4: Access Prometheus dashboard (port-forward in background)
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 &
sleep 3

echo "✓ Prometheus dashboard: http://localhost:9090"
echo "  (Wait 30-60 seconds for data collection to start)"

# Step 5: Access Grafana dashboard (alternative visualization)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
sleep 3

echo "✓ Grafana dashboard: http://localhost:3000"
echo "  Username: admin"
echo "  Password: admin123"

# Step 6: Verify metrics are being scraped
# In Prometheus UI (http://localhost:9090):
# - Go to Status → Targets
# - Should see multiple green endpoints for: prometheus, kubelet, kube-state-metrics, etc.

# Example Prometheus queries (in http://localhost:9090/graph):
# - rate(container_cpu_usage_seconds_total[5m])     # CPU usage
# - container_memory_usage_bytes                     # Memory usage
# - kubelet_pod_start_duration_seconds_count         # Pod startup times

exit
```

**What Prometheus does:**
- ✅ Collects metrics from all K8s components
- ✅ Stores time-series data for 7 days
- ✅ Provides dashboards to visualize performance
- ✅ Grafana provides prettier visualizations

---

### Step 6.4: Install ArgoCD (GitOps) - OPTIONAL +4 Points

**Two paths:**
- **Path A (No GitHub):** Just install and demo locally
- **Path B (With GitHub):** Connect to your GitHub repo for automatic deployments

#### Path A: Install ArgoCD Locally (5 min)

```bash
vagrant ssh fk-control

# Step 1: Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Step 2: Install ArgoCD
echo "Installing ArgoCD (this takes ~2-3 minutes)..."
helm install argocd argo/argo-cd \
  -n argocd \
  --create-namespace \
  --set server.service.type=LoadBalancer

# Step 3: Wait for ArgoCD pods
sleep 30
kubectl get pods -n argocd
# Should see: argocd-server, argocd-repo-server, argocd-controller-manager, etc.

# Step 4: Get admin password (automatically generated)
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD admin password: $ARGOCD_PASSWORD"

# Step 5: Access ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8443:443 &
sleep 3

echo "✓ ArgoCD UI: https://localhost:8443"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo "  (Ignore SSL certificate warning - it's self-signed)"

# Step 6: In ArgoCD UI, you can create an Application manually
# Applications → New App → Fill in:
#   - Application name: fk-webstack
#   - Project: default
#   - Repository URL: (any git repo with K8s manifests)
#   - Path: kubernetes/
#   - Cluster: https://kubernetes.default.svc
#   - Namespace: fk-webstack

exit
```

#### Path B: Connect to GitHub for Auto-Deployment (10 min)

**⚠️ REQUIRES:** GitHub account + your project pushed to GitHub

```bash
# In your GitHub repo, create branch: kubernetes/manifests.yaml

vagrant ssh fk-control

# Step 1-5: (Same as Path A above)

# Step 6: In ArgoCD UI, create Application:
# - Application name: fk-webstack-auto
# - Repository URL: https://github.com/YOUR_USERNAME/YOUR_REPO
# - Path: CleanWebserver/kubernetes/
# - Cluster: https://kubernetes.default.svc
# - Namespace: fk-webstack
# - Click "Create"

# Step 7: ArgoCD now auto-deploys whenever you push to GitHub!
# To test: Make change to manifests.yaml → git push → ArgoCD auto-deploys

exit
```

**What ArgoCD does:**
- ✅ Watches Git repository for changes
- ✅ Automatically deploys new manifests to cluster
- ✅ Provides Git as source of truth (GitOps)
- ✅ Shows deployment status in UI

---

### Step 6.5: Summary - Points for Advanced Features

```
✅ HPA Auto-scaling        = Already in base deployment (+0 bonus, part of requirement)
✅ Healthchecks            = Already in manifests.yaml (+1 bonus)
✅ 2 Worker Nodes          = Already in Vagrantfile (+1 bonus)

⏳ cert-manager (HTTPS)    = +2 points (Step 6.2 above)
⏳ Prometheus (Monitoring) = +2 points (Step 6.3 above)
⏳ ArgoCD (GitOps)         = +4 points (Step 6.4 above)

TOTAL IF ALL DONE: 18/20 (base+healthcheck+workers) + 8/20 (optional) = 20/20 ✅
```

---

### Troubleshooting Phase 6

**cert-manager not ready:**
```bash
kubectl describe clusterissuer fk-selfsigned
kubectl describe certificate fk-webstack-cert -n fk-webstack
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager
```

**Prometheus not collecting data:**
```bash
# Check targets
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Then visit: http://localhost:9090/targets

# Check scrape configs
kubectl get prometheus -n monitoring -o yaml | grep -A 20 "scrapeInterval"
```

**ArgoCD UI not loading:**
```bash
# Check service
kubectl get svc -n argocd

# Check logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Re-port-forward
kubectl port-forward -n argocd svc/argocd-server 8443:443
```

---

## Troubleshooting

### Problem: Pods stuck in ImagePullBackOff

**Solution:**
```bash
# Verify images are loaded in cluster
vagrant ssh fk-control
sudo crictl images | grep fk-

# If missing, rebuild on that node:
docker build -t fk-api:1.0 /vagrant/containers/api
docker build -t fk-frontend:1.0 /vagrant/containers/frontend
```

### Problem: MongoDB pod not running

**Solution:**
```bash
# Check logs
kubectl logs -n fk-webstack fk-mongodb-xxx

# If init job issue:
kubectl describe pod -n fk-webstack fk-mongodb-xxx
```

### Problem: API can't connect to MongoDB

**Solution:**
```bash
# Verify MongoDB service exists
kubectl get svc -n fk-webstack fk-mongodb

# Test connectivity from API pod
kubectl exec -it fk-api-xxx -n fk-webstack -- curl http://fk-mongodb:27017
```

### Problem: Cluster won't initialize

**Solution:**
```bash
# Destroy and restart from scratch
vagrant destroy -f
vagrant up
# (Takes 15-20 minutes)
```

---

## Cleanup

```bash
# Stop cluster (keeps VMs for reuse)
vagrant halt

# Destroy cluster completely
vagrant destroy -f

# Stop Docker containers
docker-compose down

# Remove Docker images
docker rmi fk-api:1.0 fk-frontend:1.0
```

---

## Summary

**Phase 1:** Docker containers built and tested locally (✅ 5 min)  
**Phase 2:** Kubernetes cluster created with Vagrant (✅ 20 min)  
**Phase 3:** Images loaded to cluster (✅ 5 min)  
**Phase 4:** Application deployed to Kubernetes (✅ 10 min)  
**Phase 5:** Test everything works (✅ 5 min)  
**Phase 6:** Optional features (⏳ 10-15 min each)  

**Total:** ~60 minutes for complete working setup

---

**Next:** See ARCHITECTURE.md for system design details, or TESTING.md for verification steps.
