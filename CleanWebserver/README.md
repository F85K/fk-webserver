# FK Webstack - Clean Kubernetes Deployment

**Student:** Frank Koch (FK)  
**Project:** Kubernetes Cluster with Multi-Container Stack  
**Date:** February 2026

---

## 📋 Project Overview

This project implements a complete 3-tier web application stack deployed on a kubeadm Kubernetes cluster:
- **Frontend:** lighttpd (web server)
- **API:** FastAPI (Python backend)
- **Database:** MongoDB (NoSQL database)

**Stack Target:** 20/20 points
- Base: 10/20 (kubeadm cluster with 2 workers)
- Extra: +2/20 (HTTPS/cert-manager), +1/20 (healthchecks), +2/20 (Prometheus), +4/20 (ArgoCD/GitOps), +1/20 (extra workers)

---

## 🏗️ Project Structure

```
CleanWebserver/
├── README.md                          # This file - project overview
├── ROADMAP.md                         # Step-by-step setup instructions
├── ARCHITECTURE.md                    # System design and components
├── docker-compose.yaml                # Local testing (optional)
│
├── containers/                        # Docker images (built first, tested locally)
│   ├── api/
│   │   ├── Dockerfile                # FastAPI container recipe
│   │   ├── app/
│   │   │   └── main.py              # API endpoints
│   │   └── requirements.txt          # Python dependencies
│   ├── frontend/
│   │   ├── Dockerfile                # lighttpd container recipe
│   │   ├── index.html                # Web UI with JavaScript
│   │   └── lighttpd.conf             # Web server config
│   └── mongodb/
│       └── Dockerfile                # MongoDB container recipe
│
├── kubernetes/                        # Kubernetes manifests (applied to cluster)
│   ├── 00-namespace.yaml             # Create fk-webstack namespace
│   ├── 01-configmap.yaml             # MongoDB initialization data
│   ├── 02-mongodb-deployment.yaml    # MongoDB pod
│   ├── 03-api-deployment.yaml        # FastAPI pod with 2 replicas
│   ├── 04-frontend-deployment.yaml   # lighttpd pod
│   ├── 05-services.yaml              # ClusterIP services
│   ├── 06-hpa.yaml                   # Horizontal Pod Autoscaler (scale 2-4)
│   ├── 07-healthcheck.yaml           # Liveness/readiness probes
│   └── optional/
│       ├── cert-manager-issuer.yaml  # HTTPS certificates
│       ├── prometheus.yaml            # Metrics monitoring
│       └── argocd-application.yaml    # GitOps deployment
│
├── vagrant/                           # Local VM provisioning (kubeadm setup)
│   ├── Vagrantfile                   # 3-node cluster definition (1 control + 2 workers)
│   ├── scripts/
│   │   ├── 01-base-setup.sh          # Install Docker, kubeadm tools
│   │   ├── 02-control-plane-init.sh  # Initialize cluster
│   │   ├── 03-worker-join.sh         # Join worker nodes
│   │   └── 04-load-images.sh         # Load Docker images to containerd
│   └── README.md                      # Vagrant setup guide
│
├── scripts/                           # Deployment automation
│   ├── setup-cluster.sh              # One-command cluster setup
│   ├── deploy-stack.sh               # Deploy application
│   └── deploy-argocd.sh              # Install ArgoCD (optional)
│
└── docs/                              # Documentation
    ├── TESTING.md                    # How to test application
    ├── TROUBLESHOOTING.md            # Common issues and fixes
    └── ARCHITECTURE.md               # System design details
```

---

## 🚀 Quick Start (5 Minutes)

### Prerequisites
- Windows PC with VirtualBox installed
- Vagrant installed
- Git (optional, for pushing to GitHub)

### Deploy Everything

```powershell
# 1. Navigate to project
cd CleanWebserver

# 2. Start cluster and deploy (first run: 15-20 minutes)
vagrant up

# 3. Verify deployment
vagrant ssh fk-control -c "kubectl get pods -n fk-webstack"

# 4. Access frontend
vagrant ssh fk-control -c "kubectl port-forward -n fk-webstack svc/fk-frontend 8080:80"
# Open browser: http://localhost:8080
```

---

## 📋 Deployment Steps (Detailed)

See **ROADMAP.md** for step-by-step instructions.

### Phase 1: Docker Containers (Local Testing)
1. Build API image: `docker build -t fk-api:latest ./containers/api`
2. Build Frontend image: `docker build -t fk-frontend:latest ./containers/frontend`
3. Test with docker-compose: `docker-compose up`

### Phase 2: Kubernetes Cluster (Vagrant)
1. Create 3 VMs: `vagrant up`
2. Verify nodes ready: `vagrant ssh fk-control -c "kubectl get nodes"`
3. Load images to cluster: `vagrant ssh fk-control -c "bash /vagrant/scripts/04-load-images.sh"`

### Phase 3: Deploy Application
1. Apply manifests: `vagrant ssh fk-control -c "kubectl apply -f /vagrant/kubernetes/"`
2. Wait for pods: `vagrant ssh fk-control -c "kubectl get pods -n fk-webstack --watch"`
3. Test frontend/API

### Phase 4: Optional Features
- **HTTPS:** Install cert-manager
- **Monitoring:** Install Prometheus
- **GitOps:** Install ArgoCD via Helm

---

## 📝 File Documentation

### Container Files (Docker)

**containers/api/main.py**
- Implements 2 required endpoints:
  - `/api/name` - GET name from MongoDB
  - `/api/container-id` - GET container ID
- Automatically detects MongoDB changes

**containers/frontend/index.html**
- Displays "Frank Koch" name from API
- Auto-refreshes every 5 seconds
- Shows container ID
- Pure JavaScript (no frameworks)

### Kubernetes Files (YAML)

**kubernetes/00-namespace.yaml**
- Creates isolated namespace: `fk-webstack`
- Prevents conflicts with other applications

**kubernetes/02-mongodb-deployment.yaml**
- 1 MongoDB replica
- Persistent data (configurable)
- Internal service on port 27017

**kubernetes/03-api-deployment.yaml**
- 2 FastAPI replicas (HPA scales 2-4)
- Livenessprobes (restart if unhealthy)
- Readiness probes (traffic only when ready)
- Connects to MongoDB

**kubernetes/06-hpa.yaml**
- Horizontal Pod Autoscaler
- Target: 50% CPU usage
- Min replicas: 2, Max: 4

### Vagrant Files (VM Setup)

**Vagrantfile**
- Defines 3 VMs: fk-control, fk-worker1, fk-worker2
- Network: 192.168.56.0/24 (VirtualBox host-only)
- Provisioning: Runs shell scripts in order

**scripts/01-base-setup.sh**
- Installs Docker 28.2.2
- Installs containerd 1.7.28
- Configures iptables/networking

**scripts/02-control-plane-init.sh**
- Installs kubeadm, kubelet, kubectl
- Initializes cluster: `kubeadm init`
- Installs Flannel CNI
- Exports join token for workers

---

## ✅ Success Criteria

- [ ] Docker images build successfully
- [ ] 3 Kubernetes nodes (1 control + 2 workers) all Ready
- [ ] FK webstack namespace created
- [ ] All pods Running (MongoDB, API 2x, Frontend)
- [ ] Frontend accessible on localhost:8080
- [ ] API endpoints respond correctly
- [ ] Database changes reflect on frontend (after refresh)
- [ ] Healthchecks working (pod restarts on failure)
- [ ] HPA scaling works (load test triggers scale-up)

---

## 📚 Additional Documentation

- **ROADMAP.md** - Complete step-by-step setup guide
- **ARCHITECTURE.md** - System design and component interactions
- **TESTING.md** - How to verify everything works
- **TROUBLESHOOTING.md** - Common issues and solutions

---

## 🔗 External Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubeadm Cluster Setup](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Vagrant Docs](https://www.vagrantup.com/docs)
- [FastAPI Docs](https://fastapi.tiangolo.com/)
- [MongoDB Docs](https://docs.mongodb.com/)

---

**Last Updated:** February 1, 2026
