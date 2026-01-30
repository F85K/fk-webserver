# FK Webstack – Complete Project Documentation

**Student:** Frank Koch (FK)  
**Project:** Kubernetes Web Application Stack  
**Stack:** lighttpd + FastAPI + MongoDB  
**Cluster:** minikube  

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Project Structure](#project-structure)
3. [File-by-File Explanation](#file-by-file-explanation)
4. [Docker Compose Setup](#docker-compose-setup)
5. [Kubernetes Setup](#kubernetes-setup)
6. [Deployment Instructions](#deployment-instructions)
7. [Testing & Verification](#testing--verification)
8. [Extra Features](#extra-features)

---

## Project Overview

### Purpose
This project demonstrates a **full-stack web application** deployed on Kubernetes (minikube) with:
- **Frontend:** lighttpd serving static HTML/JavaScript
- **API:** FastAPI (Python) serving REST endpoints
- **Database:** MongoDB storing user data

### Requirements Met
- ✅ Docker Compose stack (basispunten: 5/20)
- ✅ Kubernetes deployment op minikube (basispunten: 10/20)
- ✅ HTTPS via cert-manager (extra: +2/20)
- ✅ Extra worker node + scaling (extra: +2/20)
- ✅ Healthchecks + auto-restart (extra: +2/20)
- ✅ HPA (Horizontal Pod Autoscaler) (extra: +2/20)
- ✅ Prometheus monitoring (extra: +2/20)
- ✅ ArgoCD GitOps workflow (extra: +4/20)

**Potential Total:** 24/20

---

## Project Structure

```
WebserverLinux/
├── AItext.txt                  # Project assignment details
├── docker-compose.yaml         # Docker Compose for local testing
├── index.html                  # Root index (not used, frontend/index.html is active)
├── .gitignore                  # Git ignore file
│
├── frontend/                   # Frontend container
│   ├── Dockerfile              # Builds lighttpd container
│   ├── lighttpd.conf           # Lighttpd configuration
│   └── index.html              # Main HTML page
│
├── api/                        # API container
│   ├── Dockerfile              # Builds FastAPI container
│   ├── requirements.txt        # Python dependencies
│   └── app/
│       └── main.py             # FastAPI application
│
├── db/                         # Database initialization
│   └── init/
│       └── init.js             # MongoDB seed script
│
├── docs/                       # Documentation
│   ├── report.md               # Main documentation
│   ├── stappen.md              # Step-by-step instructions
│   └── naam-wijzigen.md        # How to change name in DB
│
└── k8s/                        # Kubernetes manifests
    ├── 00-namespace.yaml       # Namespace definition
    ├── 10-mongodb-deployment.yaml
    ├── 11-mongodb-service.yaml
    ├── 12-mongodb-init-configmap.yaml
    ├── 13-mongodb-init-job.yaml
    ├── 20-api-deployment.yaml
    ├── 21-api-service.yaml
    ├── 22-api-hpa.yaml
    ├── 30-frontend-deployment.yaml
    ├── 31-frontend-service.yaml
    ├── 40-ingress.yaml
    ├── 50-cert-issuer.yaml
    ├── 51-selfsigned-issuer.yaml
    └── 60-argocd-application.yaml
```

---

## File-by-File Explanation

### Root Files

#### `AItext.txt`
- **Purpose:** Contains the original project assignment
- **Content:** Requirements, grading criteria, student info (FK)

#### `docker-compose.yaml`
- **Purpose:** Defines all 3 containers for local Docker testing
- **Services:**
  - `fk-mongo`: MongoDB database
  - `fk-api`: FastAPI backend
  - `fk-frontend`: lighttpd frontend
- **Ports:**
  - Frontend: 8080 → 80
  - API: 8000 → 8000
  - MongoDB: 27017 → 27017
- **Dependencies:** API depends on mongo, frontend depends on API

#### `.gitignore`
- **Purpose:** Excludes temporary/sensitive files from Git
- **Excludes:** Python cache, node_modules, logs, secrets, IDE files

---

### Frontend Files

#### `frontend/Dockerfile`
```dockerfile
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y lighttpd
...
CMD ["lighttpd", "-D", "-f", "/etc/lighttpd/lighttpd.conf"]
```
- **Purpose:** Builds a lightweight lighttpd web server
- **Base Image:** Debian bookworm-slim
- **Installs:** lighttpd package
- **Copies:** lighttpd.conf and index.html
- **Runs:** lighttpd in foreground (-D flag)

#### `frontend/lighttpd.conf`
- **Purpose:** Configures lighttpd server
- **Key Settings:**
  - Document root: `/var/www/html`
  - Port: 80
  - Logs to stdout/stderr (for Docker)
  - MIME types for HTML/JS/CSS
  - No user/group (runs as root in container)

#### `frontend/index.html`
- **Purpose:** Main web page shown to user
- **Features:**
  - Displays "Milestone 2" heading
  - Fetches user name from API via JavaScript
  - Uses `fetch()` to call `/api/name`
  - Dynamically updates `<span id="user">`
- **Logic:**
  - Detects localhost vs Kubernetes
  - Uses `http://localhost:8000/api/name` for Docker
  - Uses `/api/name` for Kubernetes (via Ingress)

---

### API Files

#### `api/Dockerfile`
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app /app/app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```
- **Purpose:** Builds Python FastAPI container
- **Base Image:** Python 3.11 slim
- **Installs:** fastapi, uvicorn, pymongo
- **Runs:** Uvicorn ASGI server on port 8000

#### `api/requirements.txt`
- **Purpose:** Lists Python dependencies
- **Packages:**
  - `fastapi==0.115.6`: Web framework
  - `uvicorn[standard]==0.30.6`: ASGI server
  - `pymongo==4.8.0`: MongoDB driver

#### `api/app/main.py`
- **Purpose:** FastAPI application with REST endpoints
- **Endpoints:**
  - `GET /api/name`: Returns `{"name": "Frank Koch"}` from MongoDB
  - `GET /api/container-id`: Returns `{"container_id": "..."}` (hostname)
  - `GET /health`: Returns `{"status": "ok"}` (for healthchecks)
- **Configuration:**
  - CORS enabled (allows frontend to call API)
  - MongoDB connection via environment variables
  - Default values if env vars missing
- **Database Logic:**
  - Connects to MongoDB at `mongodb://fk-mongodb:27017`
  - Reads from database `fkdb`, collection `profile`
  - Queries `{key: "name"}` and returns `value` field

---

### Database Files

#### `db/init/init.js`
- **Purpose:** MongoDB initialization script
- **Function:** Seeds database with initial data
- **Logic:**
  - Switches to database `fkdb`
  - Upserts document: `{key: "name", value: "Frank Koch"}`
  - Used by:
    - Docker Compose: mounted in `/docker-entrypoint-initdb.d/`
    - Kubernetes: run via ConfigMap + Job

---

### Documentation Files

#### `docs/report.md`
- **Purpose:** Main project documentation
- **Content:**
  - Architecture diagram
  - File explanations
  - Deployment steps for minikube
  - Extra features explanation
  - Proof of extra points

#### `docs/stappen.md`
- **Purpose:** Simple step-by-step deployment guide
- **Content:**
  - Short commands for each deployment step
  - What to fill in (domain, repo URL)

#### `docs/naam-wijzigen.md`
- **Purpose:** How to change the name in MongoDB
- **Content:**
  - Docker Compose method
  - Kubernetes method
  - Uses `mongosh` to update database

---

### Kubernetes Manifests

#### `k8s/00-namespace.yaml`
- **Purpose:** Creates isolated namespace `fk-webstack`
- **Why:** Keeps all resources organized and separate

#### `k8s/10-mongodb-deployment.yaml`
- **Purpose:** Deploys MongoDB pod
- **Config:**
  - 1 replica (single instance)
  - Image: `mongo:6`
  - Port: 27017
  - Storage: `emptyDir` (temporary, resets on pod restart)
- **Labels:** `app: fk-mongodb`

#### `k8s/11-mongodb-service.yaml`
- **Purpose:** Exposes MongoDB internally in cluster
- **Type:** ClusterIP (internal only)
- **Port:** 27017
- **Selector:** `app: fk-mongodb`

#### `k8s/12-mongodb-init-configmap.yaml`
- **Purpose:** Stores init.js script as ConfigMap
- **Content:** Same as `db/init/init.js`
- **Used by:** Init Job

#### `k8s/13-mongodb-init-job.yaml`
- **Purpose:** Runs init script once at startup
- **Logic:**
  1. `initContainer`: Waits for MongoDB to be ready (using `nc`)
  2. `container`: Runs `mongosh` with init script
- **RestartPolicy:** OnFailure (retries if fails)

#### `k8s/20-api-deployment.yaml`
- **Purpose:** Deploys FastAPI pods
- **Config:**
  - 2 replicas (for load balancing)
  - Image: `fk-api:latest` (built locally)
  - Port: 8000
  - Environment variables: MONGO_URL, MONGO_DB, etc.
  - **Liveness Probe:** Checks `/health` every 10s (restarts if unhealthy)
  - **Readiness Probe:** Checks `/health` every 5s (stops traffic if not ready)
  - **Resources:**
    - Requests: 100m CPU, 128Mi RAM
    - Limits: 500m CPU, 256Mi RAM
- **Why 2 replicas?** Shows scaling across nodes

#### `k8s/21-api-service.yaml`
- **Purpose:** Load balances traffic to API pods
- **Type:** ClusterIP (internal)
- **Port:** 8000
- **Selector:** `app: fk-api`

#### `k8s/22-api-hpa.yaml`
- **Purpose:** Auto-scales API pods based on CPU usage
- **Config:**
  - Min replicas: 2
  - Max replicas: 4
  - Target CPU: 50%
- **Result:** Adds/removes pods when CPU > 50% or < 50%

#### `k8s/30-frontend-deployment.yaml`
- **Purpose:** Deploys lighttpd frontend
- **Config:**
  - 1 replica
  - Image: `fk-frontend:latest`
  - Port: 80
  - Resources: 50m CPU, 64Mi RAM

#### `k8s/31-frontend-service.yaml`
- **Purpose:** Exposes frontend internally
- **Type:** ClusterIP
- **Port:** 80

#### `k8s/40-ingress.yaml`
- **Purpose:** Routes external traffic to frontend and API
- **Config:**
  - Host: `fk.local` (for local testing)
  - Paths:
    - `/` → frontend service
    - `/api` → API service
  - TLS: Enabled with cert-manager
  - Annotations:
    - `kubernetes.io/ingress.class: nginx`
    - `cert-manager.io/cluster-issuer: fk-selfsigned` (for local)
- **Result:** Single domain serves both frontend and API

#### `k8s/50-cert-issuer.yaml`
- **Purpose:** Let's Encrypt issuer for **public** certificates
- **Config:**
  - Email: `r1034515@student.thomasmore.be`
  - ACME server: Let's Encrypt production
  - Solver: HTTP-01 challenge
- **Note:** Requires public domain to work

#### `k8s/51-selfsigned-issuer.yaml`
- **Purpose:** Self-signed issuer for **local** testing
- **Config:** Simple self-signed certificate
- **Result:** HTTPS works locally (browser shows warning)

#### `k8s/60-argocd-application.yaml`
- **Purpose:** ArgoCD GitOps configuration
- **Config:**
  - Repo: `https://github.com/F85K/minikube`
  - Path: `k8s/`
  - Target: `fk-webstack` namespace
  - Sync policy: Automated (auto-sync, auto-prune, self-heal)
- **Result:** ArgoCD watches Git repo and auto-deploys changes

---

## Docker Compose Setup

### Purpose
Test the stack locally before deploying to Kubernetes.

### Commands
```powershell
# Start all containers
docker compose up -d --build

# Check status
docker compose ps

# View logs
docker compose logs -f

# Stop
docker compose down
```

### Testing
- Frontend: http://localhost:8080
- API name: http://localhost:8000/api/name
- API container-id: http://localhost:8000/api/container-id
- API health: http://localhost:8000/health

---

## Kubernetes Setup

### Prerequisites
- minikube installed
- kubectl installed
- Docker Desktop running

### Step 1: Start minikube + extra worker
```powershell
minikube start
minikube node add
kubectl get nodes  # Should show 2 nodes
```

### Step 2: Enable Ingress
```powershell
minikube addons enable ingress
```

### Step 3: Build images in minikube
```powershell
# Point Docker to minikube
minikube -p minikube docker-env | Invoke-Expression

# Build images
docker build -t fk-api:latest ./api
docker build -t fk-frontend:latest ./frontend
```

### Step 4: Deploy all manifests
```powershell
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/10-mongodb-deployment.yaml
kubectl apply -f k8s/11-mongodb-service.yaml
kubectl apply -f k8s/12-mongodb-init-configmap.yaml
kubectl apply -f k8s/13-mongodb-init-job.yaml
kubectl apply -f k8s/20-api-deployment.yaml
kubectl apply -f k8s/21-api-service.yaml
kubectl apply -f k8s/22-api-hpa.yaml
kubectl apply -f k8s/30-frontend-deployment.yaml
kubectl apply -f k8s/31-frontend-service.yaml
kubectl apply -f k8s/51-selfsigned-issuer.yaml
kubectl apply -f k8s/40-ingress.yaml
```

### Step 5: Install cert-manager
```powershell
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
```

### Step 6: Add local DNS
Edit `C:\Windows\System32\drivers\etc\hosts` (as Administrator):
```
127.0.0.1 fk.local
```

### Step 7: Access app
```powershell
minikube tunnel  # Run in separate terminal
```
Then open: https://fk.local

---

## Testing & Verification

### Docker Compose Tests
```powershell
# Test API endpoints
curl http://localhost:8000/api/name
# Expected: {"name":"Frank Koch"}

curl http://localhost:8000/api/container-id
# Expected: {"container_id":"..."}

curl http://localhost:8000/health
# Expected: {"status":"ok"}

# Test frontend
curl http://localhost:8080
# Expected: HTML with "Milestone 2"
```

### Kubernetes Tests
```powershell
# Check all resources
kubectl get all -n fk-webstack

# Check pods are running
kubectl get pods -n fk-webstack
# Expected: mongodb, api (2 pods), frontend (1 pod)

# Check HPA
kubectl get hpa -n fk-webstack
# Expected: fk-api-hpa with 2-4 replicas

# Check pod distribution
kubectl get pods -o wide -n fk-webstack
# Expected: pods spread across 2 nodes

# Check ingress
kubectl get ingress -n fk-webstack
# Expected: fk-ingress with fk.local host

# Check certificate
kubectl get certificate -n fk-webstack
# Expected: certificate in Ready state

# Test endpoints via Ingress
curl -k https://fk.local/api/name
# Expected: {"name":"Frank Koch"}
```

---

## Extra Features

### 1. HTTPS with cert-manager (+2/20)
- **File:** `k8s/51-selfsigned-issuer.yaml`
- **Proof:** Browser shows HTTPS (self-signed for local)
- **Public certificate:** Change to `k8s/50-cert-issuer.yaml` with real domain

### 2. Extra worker node + scaling (+2/20)
- **Command:** `minikube node add`
- **Proof:** `kubectl get nodes` shows 2+ nodes
- **File:** `k8s/20-api-deployment.yaml` (2 replicas)
- **Proof:** `kubectl get pods -o wide` shows pods on different nodes

### 3. Healthchecks + auto-restart (+2/20)
- **File:** `k8s/20-api-deployment.yaml`
- **Lines:** `livenessProbe` and `readinessProbe`
- **Test:** Kill API process, pod auto-restarts

### 4. HPA (Horizontal Pod Autoscaler) (+2/20)
- **File:** `k8s/22-api-hpa.yaml`
- **Proof:** `kubectl get hpa -n fk-webstack`
- **Test:** Generate load, watch pods scale up

### 5. Prometheus monitoring (+2/20)
- **Installation:**
```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install fk-monitoring prometheus-community/kube-prometheus-stack
```
- **Access Grafana:**
```powershell
kubectl port-forward -n default svc/fk-monitoring-grafana 3000:80
```
Open http://localhost:3000 (admin/prom-operator)

### 6. ArgoCD GitOps (+4/20)
- **File:** `k8s/60-argocd-application.yaml`
- **Installation:**
```powershell
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd --namespace argocd --create-namespace
```
- **Access ArgoCD UI:**
```powershell
kubectl port-forward -n argocd svc/argocd-server 8080:443
```
- **Login:** Get password with:
```powershell
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

---

## Summary

This project demonstrates a complete cloud-native web application with:
- **3-tier architecture** (frontend, API, database)
- **Docker Compose** for local development
- **Kubernetes** deployment on minikube
- **Auto-scaling** (HPA)
- **High availability** (multiple replicas, health checks)
- **HTTPS** (cert-manager)
- **Monitoring** (Prometheus + Grafana)
- **GitOps** (ArgoCD)

All code is documented, tested, and follows best practices for a 2nd-year IT student project.
