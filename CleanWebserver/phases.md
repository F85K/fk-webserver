# FK Webstack - Project Requirements & Implementation Phases

**Project Assignment:** Create a 3-tier web application stack (Frontend + API + Database) deployed on Kubernetes

**Student:** Frank Koch (FK)  
**Stack:** lighttpd (Frontend) + FastAPI (API) + MongoDB (Database)  
**Deployment Target:** kubeadm Kubernetes cluster (3 nodes minimum: 1 control + 2 workers)

---

## CORE REQUIREMENTS (from AItext.txt & project-overview.md)

### Application Stack (3 Containers)

#### 1. Frontend Container - lighttpd
- **Image:** Debian with lighttpd web server
- **Port:** 80 (internal), 8080 (docker-compose), 80 (kubernetes)
- **Files:** Must include `/var/www/html/index.html` (user-provided, NEVER EDIT)
- **Behavior:**
  - Serves static HTML/JS page
  - Displays: `<span id="nameDisplay">"Frank Koch" has reached milestone 2!</span>`
  - Calls API endpoint `/api/name` every 5 seconds
  - Calls API endpoint `/api/container-id` every 5 seconds
  - Updates display with fetched name from database
  - Shows container ID of API pod
  - Shows last update timestamp
  - Must handle both Docker (localhost:8000) and Kubernetes (via proxy)

#### 2. API Container - FastAPI (Python)
- **Image:** Python 3.11 slim
- **Port:** 8000
- **Dependency:** MongoDB (must wait for MongoDB ready before starting)
- **Endpoints:**
  - `GET /api/name`
    - Query: MongoDB collection `profile` for document with name field
    - Response: `{"name": "Frank Koch"}` or `{"name": "<value_from_db>"}`
    - Behavior: Fetches from database (not hardcoded)
  - `GET /api/container-id`
    - Response: `{"container_id": "<hostname>"}` (gets from socket.gethostname())
  - `GET /health`
    - Response: `{"status": "ok"}` (for Kubernetes liveness/readiness probes)
  - Other endpoints: `/`, `/api/stats` (optional)
- **Database Connection:**
  - Connection string: `mongodb://fk-mongodb:27017` (Docker) or `mongodb://fk-mongodb:27017` (Kubernetes DNS)
  - Database: `fkdb`
  - Collection: `profile`
  - Document format: `{name: "Frank Koch"}` or `{name: "Any Name"}`
- **Health Checks:** Must include liveness probe (restart if unhealthy) and readiness probe (only accept traffic when ready)
- **Scaling:** Minimum 2 replicas for load balancing

#### 3. Database Container - MongoDB
- **Image:** mongo:6
- **Port:** 27017
- **Initial Data:** Must initialize with document `{name: "Frank Koch"}` in database `fkdb`, collection `profile`
- **Initialization:** Use `/docker-entrypoint-initdb.d/init.js` script
- **Persistence:** For docker-compose, data persists in volume. For Kubernetes, can use emptyDir (resets on restart - acceptable for school project)

### Database Schema
```javascript
// fkdb.profile collection
{
  _id: ObjectId,
  name: "Frank Koch"  // Required field - API queries for this
}
```

**Key Requirement:** When name is updated in MongoDB (via `db.profile.updateOne({name: "Frank Koch"}, {$set: {name: "New Name"}})`), the frontend auto-refreshes every 5 seconds and displays the new name.

---

## DEPLOYMENT PHASES

### Phase 1: Local Testing (Docker Compose)
**Scope:** Test 3 containers work together locally before Kubernetes  
**Files Needed:**
- `docker-compose.yaml` - defines 3 services with networking and health checks
- `containers/api/Dockerfile` - FastAPI image
- `containers/api/requirements.txt` - Python dependencies (fastapi, uvicorn, pymongo)
- `containers/api/app/main.py` - FastAPI application with 3 endpoints
- `containers/frontend/Dockerfile` - lighttpd image
- `containers/frontend/lighttpd.conf` - server config (must proxy/forward to API)
- `containers/frontend/index.html` - **USER PROVIDED - DO NOT EDIT**
- `mongodb-init/init.js` - MongoDB initialization script
- `docker-compose.override.yml` - optional for secrets (in .gitignore)

**Validation:** 
- `docker-compose up -d` succeeds
- Frontend accessible at http://localhost:8080
- API accessible at http://localhost:8000/api/name
- Name displays correctly and updates on database changes

---

### Phase 2: Kubernetes Cluster
**Scope:** Create 3-node kubeadm cluster (1 control + 2 workers)  
**Tools:** Vagrant + VirtualBox + kubeadm  
**Network:** 192.168.56.0/24 (host-only), pod network 10.244.0.0/16 (Flannel CNI)  
**Files Needed:**
- `Vagrantfile` - defines 3 VMs with provisioning
- `vagrant/scripts/k8s-setup.sh` - install Docker, kubeadm, kubelet, kubectl on all nodes
- `vagrant/scripts/control-init.sh` - initialize control plane with kubeadm init
- `vagrant/scripts/worker-join-new.sh` - join worker nodes to cluster

**Validation:**
- `vagrant up` completes without errors
- `vagrant ssh fk-control -c "kubectl get nodes"` shows 3 nodes in Ready state
- `vagrant ssh fk-control -c "kubectl get pods --all-namespaces"` shows system pods running

---

### Phase 3: Build Images Inside Kubernetes
**Scope:** Build Docker images inside VMs (not on Windows)  
**Why:** Kubernetes containerd inside VMs cannot access Windows Docker Desktop images  
**Process:**
- SSH into each VM (fk-control, fk-worker1, fk-worker2)
- Run: `docker build -t fk-api:1.0 /vagrant/containers/api`
- Run: `docker build -t fk-frontend:1.0 /vagrant/containers/frontend`
- Verify: `docker images | grep fk-`

**Files Needed:** None (uses existing Dockerfiles from Phase 1)

---

### Phase 4: Deploy Application to Kubernetes
**Scope:** Deploy 3-tier stack to running cluster  
**Files Needed:**
- `kubernetes/manifests.yaml` - single file with all K8s resources:
  - Namespace: `fk-webstack`
  - Deployment: `fk-mongodb` (1 replica)
  - Service: `fk-mongodb` (ClusterIP, port 27017)
  - ConfigMap: `fk-mongo-init` (init.js script)
  - Deployment: `fk-api` (2 replicas, liveness/readiness probes)
  - Service: `fk-api` (ClusterIP, port 8000)
  - HorizontalPodAutoscaler: `fk-api-hpa` (scale 2-4 replicas at 50% CPU)
  - Deployment: `fk-frontend` (1 replica)
  - Service: `fk-frontend` (ClusterIP, port 80)

**Validation:**
- `kubectl apply -f kubernetes/manifests.yaml` succeeds
- `kubectl get pods -n fk-webstack` shows all pods running
- `kubectl get svc -n fk-webstack` shows all services
- Pod IPs pingable from within cluster

---

### Phase 5: Test Application in Kubernetes
**Scope:** Verify all functionality works in cluster  
**Process:**
- Port-forward frontend: `kubectl port-forward -n fk-webstack svc/fk-frontend 8080:80`
  - Open http://localhost:8080, verify displays work
- Port-forward API: `kubectl port-forward -n fk-webstack svc/fk-api 8000:8000`
  - `curl http://localhost:8000/api/name` returns name from DB
  - `curl http://localhost:8000/api/container-id` returns pod hostname
- Database updates: `kubectl exec -it fk-mongodb-xxx -n fk-webstack -- mongosh`
  - `use fkdb`
  - `db.profile.updateOne({name: "Frank Koch"}, {$set: {name: "New Name"}})`
  - Refresh frontend, verify name updated within 5 seconds

---

## OPTIONAL EXTRA FEATURES (for additional points)

### Phase 6.1: Horizontal Pod Autoscaling (HPA)
**Requirement:** Show API pods scaling 2-4 based on CPU usage  
**In manifests.yaml:** HorizontalPodAutoscaler targeting 50% CPU utilization  
**Testing:** Generate load, watch replicas increase  
**Points:** +2/20

### Phase 6.2: cert-manager (HTTPS)
**Requirement:** Provision TLS certificates for application  
**Implementation:**
- Install cert-manager via Helm
- Create ClusterIssuer for self-signed certificates
- Add annotations to Ingress/Services for auto-TLS
**Points:** +2/20

### Phase 6.3: Prometheus Monitoring
**Requirement:** Monitor cluster resources and application metrics  
**Implementation:**
- Install Prometheus + Grafana via Helm
- Collect metrics from kubelet, nodes, pods
- Create dashboards
**Points:** +2/20

### Phase 6.4: ArgoCD GitOps
**Requirement:** Deploy application via GitOps workflow  
**Implementation:**
- Install ArgoCD via Helm
- Create GitHub repo with manifests
- Configure ArgoCD to sync from repo
- Demonstrate auto-deployment on repo changes
**Points:** +4/20

---

## SCORING BREAKDOWN

| Item | Points | Requirements |
|------|--------|--------------|
| **Base: Docker Compose** | 5/20 | Phase 1 complete |
| **Base: Kubernetes** | 10/20 | Phases 2-5 complete, 1 control + 2 workers, app running |
| **Extra: HTTPS (cert-manager)** | +2/20 | Phase 6.2 |
| **Extra: Scaling + 2 Workers** | +1/20 | Already have 2 workers + HPA |
| **Extra: Healthchecks** | +1/20 | Liveness/readiness probes in Phase 4 |
| **Extra: Prometheus** | +2/20 | Phase 6.3 |
| **Extra: ArgoCD/GitOps** | +4/20 | Phase 6.4 |
| **TOTAL POSSIBLE** | **20+8/20** | Guaranteed 18/20, achievable 20/20 |

---

## FILE STRUCTURE

```
CleanWebserver/
├── docker-compose.yaml              # Phase 1: Local 3-service stack
├── Vagrantfile                      # Phase 2: VM definitions
│
├── containers/
│   ├── api/
│   │   ├── Dockerfile              # FastAPI image
│   │   ├── requirements.txt         # Python deps
│   │   └── app/
│   │       └── main.py              # FastAPI endpoints
│   └── frontend/
│       ├── Dockerfile              # lighttpd image
│       ├── lighttpd.conf           # server config with API proxy
│       └── index.html              # USER PROVIDED - NEVER EDIT
│
├── mongodb-init/
│   └── init.js                     # MongoDB initialization script
│
├── kubernetes/
│   └── manifests.yaml              # Phase 4: All K8s resources
│
├── vagrant/
│   └── scripts/
│       ├── k8s-setup.sh            # Phase 2: Install Docker, kubeadm
│       ├── control-init.sh         # Phase 2: Initialize control plane
│       └── worker-join-new.sh      # Phase 2: Join workers to cluster
│
└── [Documentation files]
    ├── README.md
    ├── ROADMAP.md
    ├── PROJECT_SUMMARY.md
    └── etc.
```

---

## KEY CONSTRAINTS & RULES

1. **index.html:** User-provided file. DO NOT EDIT. Must work as-is.
2. **Database Schema:** Must use `{name: "..."}` format in MongoDB, not `{key: "name", value: "..."}`.
3. **Image Names:** Use `fk-api:1.0` and `fk-frontend:1.0` (FK prefix as per requirements).
4. **API Responses:** Must return valid JSON. Frontend expects specific field names.
5. **Health Checks:** All deployments must have liveness AND readiness probes.
6. **Networking:** 
   - Docker Compose: Services communicate via service names (fk-mongodb, fk-api)
   - Kubernetes: Services communicate via DNS (fk-mongodb.fk-webstack.svc.cluster.local)
7. **Secrets:** Never commit real credentials. Use .gitignore and docker-compose.override.yml pattern.
8. **Scope:** 3-tier stack only. No extra services beyond requirements.

---

## SUCCESS CRITERIA

✅ **Phase 1:** Docker-compose runs locally, frontend shows name from MongoDB, name updatable  
✅ **Phase 2:** 3-node Kubernetes cluster running via Vagrant  
✅ **Phase 3:** Images built inside VMs, available in containerd  
✅ **Phase 4:** Application deployed to Kubernetes, pods running  
✅ **Phase 5:** All endpoints work, database updates reflected in UI  
✅ **Phase 6:** (Optional) Extra features implemented for bonus points  
✅ **Security:** No secrets in git, .gitignore configured  
✅ **Documentation:** All phases documented with clear instructions  

---

## DECISION TREE FOR AI IMPLEMENTATION

```
IF user says "start from scratch":
  1. Create docker-compose.yaml (Phase 1)
  2. Create all container files (Dockerfile, requirements.txt, main.py, index.html user-provided, lighttpd.conf)
  3. Create Vagrantfile + provisioning scripts (Phase 2)
  4. Create kubernetes/manifests.yaml (Phase 4)
  5. Create documentation
  6. Test Phase 1 locally (docker-compose)
  7. Test Phase 2 (vagrant up)

ELSE IF user says "continue":
  1. Check what phase is complete
  2. Proceed to next incomplete phase
  3. Validate before moving forward

ELSE IF user says "skip to Kubernetes":
  1. Assume Phase 1 code is working
  2. Build cluster (Phase 2)
  3. Deploy manifests (Phase 4)

CONSTRAINT: Never edit index.html. Treat it as read-only user input.
```
