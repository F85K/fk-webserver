# FK Webstack - Oral Exam Summary
**Student:** Frank Koch  
**Project:** Kubernetes Cluster met 3-Tier Web Applicatie  
**Datum:** 30 januari 2026

---

## 📋 Quick Reference - Scoring Breakdown

### Basis Requirements (10/20)
✅ **Docker Stack (5/20)** - Fully functional  
✅ **Kubernetes Cluster (10/20)** - Kubeadm met 1 control + 2 workers

### Extra Features (10/20 mogelijk)
✅ **HTTPS met cert-manager (+2/20)** - Self-signed certificaat voor fk.local  
✅ **Extra worker nodes (+1/20)** - 2 worker nodes (fk-worker1, fk-worker2)  
✅ **Healthchecks (+1/20)** - Liveness en readiness probes in API deployment  
✅ **Prometheus monitoring (+2/20)** - Complete stack met Grafana  
✅ **ArgoCD + GitOps (+4/20)** - Helm Chart deployment + auto-sync van GitHub

**TOTAAL: 20/20 punten mogelijk** ✅

---

## 🏗️ Architectuur Overzicht

```
┌─────────────────────────────────────────────────────────────┐
│                 FK WEBSTACK KUBERNETES                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────────────────────────────────┐     │
│  │  fk-control (Control Plane) - 192.168.56.10      │     │
│  │  • API Server, Scheduler, Controller Manager     │     │
│  │  • etcd (cluster state database)                 │     │
│  │  • Flannel CNI (pod networking)                  │     │
│  │  • cert-manager (certificate automation)         │     │
│  │  • ArgoCD (GitOps automation)                    │     │
│  └───────────────────────────────────────────────────┘     │
│           │                            │                    │
│     ┌─────┴──────┐            ┌───────┴──────┐            │
│     │            │            │              │            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │fk-worker1│ │fk-worker2│ │fk-frontend │fk-mongodb│    │
│  │.56.11    │ │.56.12    │ │(lighttpd)  │(db)      │    │
│  │          │ │          │ │            │          │    │
│  │fk-api-1  │ │fk-api-2  │ └────────────┘└──────────┘    │
│  │(replica) │ │(replica) │                               │
│  └──────────┘ └──────────┘                               │
│       ▲            ▲                                       │
│       └────────────┴── HPA: 2-4 replicas @ 50% CPU       │
│                                                             │
│  Ingress (HTTPS via fk.local)                             │
│   ├── / → fk-frontend (lighttpd)                          │
│   └── /api → fk-api (FastAPI LoadBalancer)               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 Technische Stack

### Infrastructure Layer
- **Virtualisatie:** Vagrant + VirtualBox
- **OS:** Ubuntu 22.04 LTS (Jammy)
- **Container Runtime:** Docker 28.2.2 + containerd 1.7.28
- **Orchestratie:** Kubernetes 1.35.0 (kubeadm deployment)
- **Networking:** Flannel CNI (pod-network-cidr: 10.244.0.0/16)

### Application Layer
- **Frontend:** lighttpd 1.4 (Debian bookworm-slim)
- **API:** FastAPI 0.115.6 + Uvicorn (Python 3.11-slim)
- **Database:** MongoDB 6 (single replica met init Job)

### DevOps Tools
- **CI/CD:** ArgoCD 2.x via Helm Chart
- **GitOps:** GitHub repo sync (https://github.com/F85K/minikube)
- **Certificate Management:** cert-manager 1.14.4
- **Monitoring:** Prometheus + Grafana (kube-prometheus-stack)
- **Autoscaling:** Horizontal Pod Autoscaler (HPA)

---

## 📦 Container Details

### 1. FK Frontend (lighttpd)
**Image:** `fk-frontend:latest`  
**Base:** debian:bookworm-slim  
**Purpose:** Serves HTML page with responsive layout and JavaScript

**Key Features:**
- **Responsive Design:** Auto-adjusts layout on window resize
- **Dynamic Content:** Fetches name from API via JavaScript fetch()
- **Environment Detection:** Auto-detects localhost vs Kubernetes
- **API Endpoints Called:** 
  - `GET /api/name` - Retrieves "Frank Koch" from MongoDB
  - `GET /api/container-id` - Shows which API pod responded

**Dockerfile Highlights:**
```dockerfile
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y lighttpd
COPY lighttpd.conf /etc/lighttpd/lighttpd.conf
COPY index.html /var/www/html/
CMD ["lighttpd", "-D", "-f", "/etc/lighttpd/lighttpd.conf"]
```

**Why lighttpd?**
- Lightweight (~10MB vs NGINX ~100MB)
- Perfect for static content
- Easy configuration
- Low resource usage

---

### 2. FK API (FastAPI)
**Image:** `fk-api:latest`  
**Base:** python:3.11-slim  
**Purpose:** REST API met database connectivity

**API Endpoints:**
1. **GET /api/name**
   - Returns: `{"name": "Frank Koch"}`
   - Source: MongoDB query `collection.find_one({"key": "name"})`
   - Used by: Frontend JavaScript

2. **GET /api/container-id**
   - Returns: `{"container_id": "<hostname>"}`
   - Shows: Which pod responded (for load balancing demo)
   - Useful for: Demonstrating ingress distribution across nodes

3. **GET /health**
   - Returns: `{"status": "ok"}`
   - Used by: Kubernetes liveness/readiness probes
   - Purpose: Auto-restart unhealthy pods

**Code Snippet:**
```python
from fastapi import FastAPI
from pymongo import MongoClient

app = FastAPI()
client = MongoClient(MONGO_URL)
db = client[MONGO_DB]

@app.get("/api/name")
async def get_name():
    doc = db.profile.find_one({"key": "name"})
    return {"name": doc.get("value", "Frank Koch")}

@app.get("/health")
async def health():
    return {"status": "ok"}
```

**Environment Variables:**
- `MONGO_URL`: mongodb://fk-mongodb.fk-webstack:27017
- `MONGO_DB`: frankdb
- `MONGO_COLLECTION`: profile

---

### 3. FK Database (MongoDB)
**Image:** mongo:6  
**Purpose:** Persistent storage voor user data

**Initialization:**
- **ConfigMap:** `12-mongodb-init-configmap.yaml` contains init.js
- **Init Job:** `13-mongodb-init-job.yaml` runs mongosh script
- **Script:** Seeds database with `{key: "name", value: "Frank Koch"}`

**init.js:**
```javascript
db = db.getSiblingDB('frankdb');
db.profile.updateOne(
  {key: "name"}, 
  {$set: {value: "Frank Koch"}}, 
  {upsert: true}
);
```

**Why Job instead of init script?**
- ConfigMap ensures script is available
- Job waits for MongoDB readiness (initContainer)
- Idempotent (can be re-run safely)
- Logs are preserved for debugging

---

## 🚀 Deployment Files Explained

### Kubernetes Manifests (13 files in k8s/)

#### Core Application
1. **00-namespace.yaml** - Creates `fk-webstack` namespace
2. **10-mongodb-deployment.yaml** - MongoDB pod (1 replica, emptyDir storage)
3. **11-mongodb-service.yaml** - ClusterIP service (port 27017)
4. **12-mongodb-init-configmap.yaml** - init.js script storage
5. **13-mongodb-init-job.yaml** - Runs initialization on startup

#### API Layer
6. **20-api-deployment.yaml** - FastAPI (2 replicas initially)
   - **Liveness Probe:** `GET /health` every 10s (restarts if fails)
   - **Readiness Probe:** `GET /health` every 5s (removes from service if fails)
   - **Resources:** 100m CPU request, 256Mi memory limit
7. **21-api-service.yaml** - ClusterIP service (port 8000) for load balancing
8. **22-api-hpa.yaml** - HPA targeting 50% CPU, scales 2→4 replicas

#### Frontend Layer
9. **30-frontend-deployment.yaml** - lighttpd (1 replica)
10. **31-frontend-service.yaml** - ClusterIP service (port 80)

#### Networking & Security
11. **40-ingress.yaml** - NGINX Ingress with TLS
    - Host: `fk.local`
    - Paths: `/` → frontend, `/api` → API
    - Certificate: `fk-selfsigned` (auto-generated by cert-manager)

12. **50-cert-issuer.yaml** - Let's Encrypt ClusterIssuer (for production)
13. **51-selfsigned-issuer.yaml** - Self-signed ClusterIssuer (for testing)

#### GitOps
14. **60-argocd-application.yaml** - ArgoCD Application CRD
    - **Source:** https://github.com/F85K/minikube (k8s/ folder)
    - **Sync Policy:** Automated (auto-sync enabled)
    - **Prune:** Yes (removes deleted resources)
    - **Self-Heal:** Yes (reverts manual changes)

---

## 🔐 HTTPS Implementation (cert-manager)

### Why cert-manager?
- **Automated:** Certificates auto-generated, renewed, and rotated
- **Industry Standard:** Used by 70%+ of Kubernetes clusters
- **Flexible:** Supports Let's Encrypt, self-signed, Vault, etc.

### How it Works:
1. **Install cert-manager CRDs:**
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
   ```

2. **Create ClusterIssuer (51-selfsigned-issuer.yaml):**
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: fk-selfsigned
   spec:
     selfSigned: {}
   ```

3. **Request Certificate in Ingress (40-ingress.yaml):**
   ```yaml
   metadata:
     annotations:
       cert-manager.io/cluster-issuer: fk-selfsigned
   spec:
     tls:
     - hosts:
       - fk.local
       secretName: fk-tls-cert
   ```

4. **cert-manager automatically:**
   - Creates private key
   - Generates certificate
   - Stores in Secret `fk-tls-cert`
   - Ingress uses Secret for HTTPS

**Demo Points:**
- Show certificate in browser (lock icon)
- Explain self-signed vs Let's Encrypt
- Show cert-manager pods: `kubectl get pods -n cert-manager`

---

## 🔄 Healthchecks Implementation

### Liveness Probe (in 20-api-deployment.yaml)
**Purpose:** Restart pod if unhealthy

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3
```

**Behavior:**
- Waits 10s after pod starts
- Checks `/health` every 10s
- If 3 consecutive failures (30s) → **Restart pod**

### Readiness Probe
**Purpose:** Remove pod from service if not ready

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 5
```

**Behavior:**
- Pod added to Service only when passing
- Traffic stops routing to unhealthy pods
- No restart, just removal from load balancing

### Demo:
```bash
# Kill API process inside pod
kubectl exec -it <api-pod> -n fk-webstack -- pkill python

# Watch pod restart
kubectl get pods -n fk-webstack --watch
```

---

## 📊 HPA (Horizontal Pod Autoscaler)

### Configuration (22-api-hpa.yaml):
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: fk-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: fk-api
  minReplicas: 2
  maxReplicas: 4
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

### How it Works:
1. **Metrics-server** collects CPU/memory usage
2. **HPA controller** checks every 15s
3. **If CPU > 50%** → Scale up (max 4 pods)
4. **If CPU < 50%** → Scale down (min 2 pods)
5. **Cooldown:** 3 min scale-up, 5 min scale-down

### Demo Load Test:
```bash
# Generate load
kubectl run load-generator --image=busybox:1.28 --restart=Never -- /bin/sh -c \
  "while sleep 0.01; do wget -q -O- http://fk-api.fk-webstack:8000/api/name; done"

# Watch HPA scale
kubectl get hpa -n fk-webstack --watch

# Expected: 2 → 3 → 4 replicas within 2-3 minutes
```

**Why HPA is Important:**
- **Cost Efficiency:** Scale down during low traffic
- **Reliability:** Scale up during traffic spikes
- **Automatic:** No manual intervention

---

## 🏢 Kubeadm Cluster Setup

### Why Kubeadm over Minikube?
- **Production-like:** Same setup as real clusters
- **Multi-node:** Can distribute pods across workers
- **Load Balancing:** Real Service distribution
- **Realistic:** Mimics enterprise deployments

### Cluster Topology:
```
fk-control (192.168.56.10):
  - Role: Control Plane (Master)
  - Components: API server, etcd, scheduler, controller-manager
  - Taints: node-role.kubernetes.io/control-plane:NoSchedule
  - Resources: 3 CPU, 3GB RAM

fk-worker1 (192.168.56.11):
  - Role: Worker Node
  - Runs: fk-api pods (via HPA), other workloads
  - Resources: 2 CPU, 2GB RAM

fk-worker2 (192.168.56.12):
  - Role: Worker Node
  - Runs: fk-api pods (via HPA), other workloads
  - Resources: 2 CPU, 2GB RAM
```

### Networking:
- **CNI:** Flannel (pod-network-cidr: 10.244.0.0/16)
- **Service CIDR:** 10.96.0.0/12 (default)
- **Private Network:** 192.168.56.0/24 (VirtualBox Host-Only)

### Initialization Process:
1. **Control Plane Init:**
   ```bash
   kubeadm init --apiserver-advertise-address=192.168.56.10 \
                --pod-network-cidr=10.244.0.0/16
   ```

2. **Install Flannel CNI:**
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
   ```

3. **Workers Join:**
   ```bash
   kubeadm join 192.168.56.10:6443 --token <token> \
     --discovery-token-ca-cert-hash sha256:<hash>
   ```

### Demo Points:
- Show nodes: `kubectl get nodes -o wide`
- Show pod distribution: `kubectl get pods -n fk-webstack -o wide`
- Verify different IPs (pods on different workers)

---

## 🔄 ArgoCD + GitOps Implementation

### Why ArgoCD?
- **Automated Deployment:** Git push → Cluster auto-updates
- **Declarative:** Git as single source of truth
- **Rollback:** Easy revert to previous Git commit
- **Visibility:** Web UI shows deployment status

### Installation (via Helm Chart):
```bash
# Add Helm repo
helm repo add argo https://argoproj.github.io/argo-helm

# Install ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --set configs.secret.argocdServerAdminPassword='admin123'
```

### ArgoCD Application (60-argocd-application.yaml):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fk-webstack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/F85K/minikube
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: fk-webstack
  syncPolicy:
    automated:
      prune: true        # Delete resources removed from Git
      selfHeal: true     # Revert manual changes
    syncOptions:
    - CreateNamespace=true
```

### GitOps Workflow:
1. **Developer** pushes change to GitHub (e.g., update API replicas)
2. **ArgoCD** detects change (polls every 3 min)
3. **ArgoCD** compares Git vs Cluster state
4. **If different** → Auto-sync to match Git
5. **Web UI** shows sync status (green = synced)

### Demo:
```bash
# Access ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Open browser: https://localhost:8080
# Login: admin / admin123 (from Helm values)

# Make change in Git: edit k8s/20-api-deployment.yaml (change replicas: 3)
git commit -am "Scale API to 3 replicas"
git push

# Watch ArgoCD detect and apply (max 3 min)
```

**Extra Points Value:** +4/20 (most valuable feature!)

---

## 📈 Prometheus + Grafana Monitoring

### Installation:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install fk-monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace
```

### What it Includes:
- **Prometheus:** Time-series metrics database
- **Grafana:** Visualization dashboards
- **Alertmanager:** Alert routing
- **Node Exporter:** Host metrics
- **kube-state-metrics:** Kubernetes resource metrics

### Key Metrics Monitored:
- **Node:** CPU, memory, disk, network
- **Pod:** CPU/memory usage per pod
- **API:** Request rate, latency, errors
- **HPA:** Current replicas, target CPU%

### Access Grafana:
```bash
kubectl port-forward -n monitoring svc/fk-monitoring-grafana 3000:80
# Open: http://localhost:3000
# Login: admin / prom-operator
```

### Demo Dashboards:
- **Kubernetes / Compute Resources / Cluster** - Overall cluster health
- **Kubernetes / Compute Resources / Namespace (Pods)** - fk-webstack pods
- **Node Exporter / Nodes** - Worker node metrics

---

## 🎯 Demo Script for Oral Exam

### Part 1: Show Infrastructure (5 min)
```bash
# 1. Show cluster nodes
kubectl get nodes -o wide

# 2. Show FK webstack components
kubectl get all -n fk-webstack

# 3. Show pods distributed across workers
kubectl get pods -n fk-webstack -o wide

# 4. Show cert-manager
kubectl get pods -n cert-manager
```

### Part 2: Test Application (5 min)
```bash
# 1. Port-forward frontend
kubectl port-forward -n fk-webstack svc/fk-frontend 80:80

# 2. Open browser: http://localhost
# Show: "Milestone 2" page with "Frank Koch" name

# 3. Test API directly
curl http://localhost:8000/api/name
# Expected: {"name":"Frank Koch"}

curl http://localhost:8000/api/container-id
# Expected: {"container_id":"fk-api-xxx-yyy"}
```

### Part 3: Demo HTTPS (3 min)
```bash
# 1. Show ingress with TLS
kubectl describe ingress fk-ingress -n fk-webstack

# 2. Show certificate
kubectl get certificate -n fk-webstack

# 3. Show cert-manager issuer
kubectl get clusterissuer fk-selfsigned
```

### Part 4: Demo Healthchecks (3 min)
```bash
# 1. Get API pod
POD=$(kubectl get pods -n fk-webstack -l app=fk-api -o jsonpath='{.items[0].metadata.name}')

# 2. Kill API process
kubectl exec -it $POD -n fk-webstack -- pkill python

# 3. Watch pod restart
kubectl get pods -n fk-webstack --watch
# Expected: Pod goes NotReady → CrashLoopBackOff → Running
```

### Part 5: Demo HPA Autoscaling (5 min)
```bash
# 1. Show current HPA status
kubectl get hpa -n fk-webstack

# 2. Generate load
kubectl run load-gen --image=busybox:1.28 --restart=Never -- /bin/sh -c \
  "while sleep 0.01; do wget -q -O- http://fk-api.fk-webstack:8000/api/name; done"

# 3. Watch HPA scale (wait 2-3 min)
kubectl get hpa -n fk-webstack --watch

# Expected: 2 → 3 → 4 replicas as CPU increases

# 4. Stop load
kubectl delete pod load-gen

# 5. Watch scale down (wait 5 min)
# Expected: 4 → 3 → 2 replicas
```

### Part 6: Demo ArgoCD GitOps (5 min)
```bash
# 1. Access ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443

# 2. Open: https://localhost:8080
# Login: admin / <password from install>

# 3. Show fk-webstack Application
# - Status should be "Synced" and "Healthy"
# - Show all resources (deployments, services, etc.)

# 4. Make change in Git
# Edit k8s/20-api-deployment.yaml: replicas: 3
git commit -am "Scale to 3"
git push

# 5. Watch ArgoCD detect and sync (refresh UI)
# Expected: Status "Out of Sync" → "Syncing" → "Synced"
```

### Part 7: Demo Prometheus (3 min)
```bash
# 1. Access Grafana
kubectl port-forward -n monitoring svc/fk-monitoring-grafana 3000:80

# 2. Open: http://localhost:3000
# Login: admin / prom-operator

# 3. Show dashboards:
# - Kubernetes / Compute Resources / Cluster
# - Show fk-webstack namespace metrics
```

---

## 📚 Documentation Files

### Project Structure:
```
docs/
├── project-overview.md         # 550+ lines comprehensive documentation
├── report.md                   # Main project report
├── stappen.md                  # Step-by-step deployment guide (Dutch)
├── naam-wijzigen.md            # How to change name in database
├── start-all.ps1               # PowerShell automation script (Kubeadm)
└── ORAL-EXAM-SUMMARY.md        # This file (exam preparation)

vagrant/
├── 01-base-setup.sh            # Docker, iptables, swap disable
├── 02-kubeadm-install.sh       # Install kubeadm tools
├── 03-control-plane-init.sh    # Initialize control plane + Flannel
├── 04-worker-join.sh           # Join workers to cluster
├── 05-deploy-argocd.sh         # Deploy ArgoCD + cert-manager + FK stack
├── README.md                   # Vagrant setup guide
└── QUICKSTART.sh               # Quick reference commands
```

---

## 🎓 Key Points for Oral Defense

### Technical Decisions Explained:

**Q: Why Kubernetes instead of just Docker Compose?**
A: Kubernetes provides:
- **High Availability:** Automatic pod restarts, self-healing
- **Scalability:** HPA auto-scales based on load
- **Load Balancing:** Service distributes traffic across pods
- **Rolling Updates:** Zero-downtime deployments
- **Enterprise Standard:** 90% of Fortune 500 use Kubernetes

**Q: Why kubeadm over minikube?**
A: 
- **Production-like:** Same tool used for real clusters
- **Multi-node:** Can demonstrate actual load distribution
- **Learning:** Better understanding of Kubernetes internals
- **Realism:** Mimics enterprise deployment process

**Q: Why FastAPI over Node.js?**
A:
- **Performance:** Async/await support, fast like Node
- **Type Safety:** Pydantic models prevent errors
- **Auto Docs:** OpenAPI/Swagger built-in at `/docs`
- **Modern:** Python 3.11 asyncio support
- **Simple:** Less boilerplate than Express.js

**Q: Why lighttpd over NGINX?**
A:
- **Lightweight:** 10MB vs 100MB (NGINX)
- **Simplicity:** Minimal config for static content
- **Performance:** Comparable for static files
- **Low Resources:** Perfect for small frontend

**Q: Why self-signed cert over Let's Encrypt?**
A:
- **Local Testing:** Let's Encrypt requires public domain
- **Development:** Self-signed works for fk.local
- **Flexibility:** Can switch to Let's Encrypt in production
- **Demonstrates Knowledge:** Shows understanding of both

### Project Highlights:

1. **Complete GitOps Workflow:** Git push → ArgoCD auto-deploys
2. **Production-Ready:** Healthchecks, autoscaling, monitoring
3. **Well-Documented:** 550+ line project-overview.md
4. **Automated:** PowerShell script for full deployment
5. **Clean Code:** All FK-prefixed (FK-api, FK-frontend, etc.)
6. **Best Practices:** Namespaces, resource limits, probes

---

## ⚠️ Common Questions & Troubleshooting

### Q: Pods stuck in Pending?
```bash
# Check node resources
kubectl describe nodes

# Check pod events
kubectl describe pod <pod-name> -n fk-webstack
```

### Q: API can't connect to MongoDB?
```bash
# Check service DNS
kubectl exec -it <api-pod> -n fk-webstack -- nslookup fk-mongodb.fk-webstack

# Check MongoDB logs
kubectl logs <mongo-pod> -n fk-webstack
```

### Q: Ingress not working?
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress configuration
kubectl describe ingress fk-ingress -n fk-webstack
```

### Q: HPA not scaling?
```bash
# Check metrics-server
kubectl get pods -n kube-system | grep metrics-server

# Check HPA metrics
kubectl get hpa -n fk-webstack
kubectl describe hpa fk-api-hpa -n fk-webstack
```

---

## 🏆 Scoring Checklist

### Basis (10/20):
- ☑ Docker Compose stack working (5/20)
  - ✓ 3 containers (frontend, API, database)
  - ✓ JavaScript fetches name from API
  - ✓ API connects to MongoDB
  
- ☑ Kubernetes cluster (10/20)
  - ✓ kubeadm cluster (1 control + 2 workers)
  - ✓ Pods deployed and running
  - ✓ Service load balancing

### Extra (10/20):
- ☑ HTTPS cert-manager (+2/20)
  - ✓ cert-manager installed
  - ✓ Self-signed ClusterIssuer
  - ✓ Ingress with TLS

- ☑ Extra worker nodes (+1/20)
  - ✓ 2 worker nodes (fk-worker1, fk-worker2)
  - ✓ Pods distributed across nodes

- ☑ Healthchecks (+1/20)
  - ✓ Liveness probes (auto-restart)
  - ✓ Readiness probes (traffic control)

- ☑ Prometheus monitoring (+2/20)
  - ✓ Prometheus stack installed
  - ✓ Grafana dashboards accessible

- ☑ ArgoCD + GitOps (+4/20)
  - ✓ ArgoCD installed via Helm Chart
  - ✓ Application synced from GitHub
  - ✓ Auto-sync enabled
  - ✓ GitOps workflow functional

**TOTAL: 20/20** ✅

---

## 📌 Final Tips

1. **Practice the demo:** Run through Part 1-7 multiple times
2. **Know your code:** Be able to explain any file
3. **Understand concepts:** Why, not just how
4. **Have backup:** Screenshots if live demo fails
5. **Be confident:** You've done all the work!

---

**Good luck with your oral exam!** 🍀

Remember: The examiner wants to see you succeed. Show confidence, explain your choices, and demonstrate your knowledge. You've built a complete, production-ready Kubernetes stack!
