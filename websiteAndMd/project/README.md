# FK Webstack - Bare Minimum Project Files

**Complete project structure with only essential files needed to deploy**

- ✅ No documentation files (all .md files excluded)
- ✅ No scripts (Vagrant provisioning scripts excluded)
- ✅ Only bare minimum to make everything work

## Project Structure

```
project/
├── Vagrantfile                          # VM definitions (3-node kubeadm cluster)
├── docker-compose.yaml                  # Docker Compose baseline (Phase 1)
├── .env.local.example                   # Environment template (DuckDNS config)
│
├── api/                                 # FastAPI source code
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app/
│       ├── main.py                      # FastAPI endpoints
│       └── __init__.py
│
├── frontend/                            # Web frontend (lighttpd + HTML)
│   ├── Dockerfile
│   ├── index.html                       # Single page app
│   └── lighttpd.conf                    # Web server config
│
├── db/                                  # Database initialization
│   └── init/
│       └── init.js                      # MongoDB init script
│
└── k8s/                                 # Kubernetes manifests (21 files, 20/20 points)
    ├── 00-namespace.yaml                # fk-webstack namespace
    ├── 08-mongodb-pv.yaml               # MongoDB volume
    ├── 09-mongodb-pvc.yaml
    ├── 10-mongodb-deployment.yaml
    ├── 11-mongodb-service.yaml
    ├── 12-mongodb-init-configmap.yaml
    ├── 13-mongodb-init-job.yaml
    ├── 15-api-configmap.yaml            # API source code as ConfigMap
    ├── 20-api-deployment.yaml           # 3 replicas
    ├── 21-api-service.yaml              # ClusterIP service
    ├── 22-api-hpa.yaml                  # Horizontal Pod Autoscaler
    ├── 25-frontend-configmap.yaml
    ├── 30-frontend-deployment.yaml
    ├── 31-frontend-service.yaml
    ├── 40-ingress.yaml                  # HTTPS Ingress (2 extra points)
    ├── 50-cert-issuer.yaml              # Certificate issuer
    ├── 50-letsencrypt-issuer.yaml       # Let's Encrypt issuer
    ├── 51-selfsigned-issuer.yaml        # Self-signed issuer (local)
    ├── 60-argocd-application.yaml       # GitOps manifests (4 extra points)
    ├── 90-demo-scale.yaml               # Demo namespace for testing
    └── 99-secrets-template.yaml         # Secrets template
```

## Quick Start

### Phase 1: Docker Compose (10/20 points)
```bash
docker-compose up -d
curl http://localhost:8080      # Frontend
curl http://localhost:8000/api/name  # API
```

### Phase 2: Kubernetes with kubeadm (20/20 points)
```bash
vagrant up                      # Create VMs
# Then see KUBEADM-MIGRATION.md for full setup

# Deploy to cluster:
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/08-*.yaml k8s/09-*.yaml k8s/10-*.yaml ...
# Or use: for f in k8s/*.yaml; do kubectl apply -f $f; done
```

## File Sizes

- **Vagrantfile**: VM configuration (3 nodes: 1 control + 2 workers)
- **docker-compose.yaml**: 26 lines
- **.env.local.example**: 2 lines (DuckDNS template)
- **api/main.py**: FastAPI with MongoDB connection + 3 endpoints
- **frontend/index.html**: Fetches name from API
- **db/init.js**: MongoDB initialization
- **k8s/ manifests**: 21 YAML files covering all requirements

## What's NOT Included

- ❌ Documentation (.md files)
- ❌ Provisioning scripts (vagrant/ folder)
- ❌ Troubleshooting guides
- ❌ Build scripts
- ❌ GitHub actions workflows
- ❌ Tests or examples
- ❌ Node.js/npm files

## What IS Included (Bare Minimum Only)

- ✅ **Vagrantfile** - Create 3 VirtualBox VMs
- ✅ **docker-compose.yaml** - Run stack locally
- ✅ **api/** - FastAPI source code
- ✅ **frontend/** - HTML + JavaScript
- ✅ **db/** - MongoDB init script
- ✅ **k8s/** - All 21 Kubernetes manifests
- ✅ **.env.local.example** - Environment template

## Deployment

### Docker Compose
```bash
# Start services
docker-compose up -d

# Test
curl http://localhost:8080
curl http://localhost:8000/health

# Stop
docker-compose down
```

### Kubernetes
```bash
# Create VMs
vagrant up

# SSH into control plane
vagrant ssh fk-control

# Then inside VM:
# 1. kubeadm init (with flags from KUBEADM-MIGRATION.md)
# 2. Install CNI (Flannel)
# 3. Join workers
# 4. Deploy manifests: kubectl apply -f k8s/

# After deployment:
kubectl get pods -n fk-webstack
kubectl get svc -n fk-webstack
```

## Points Breakdown

| Feature | Points | File |
|---------|--------|------|
| Docker Compose | 10/20 | docker-compose.yaml |
| Kubernetes deployment | 10/20 | k8s/10-30-*.yaml |
| HTTPS with cert-manager | +2/20 | k8s/40,50,51-*.yaml |
| API healthchecks | +2/20 | k8s/20-api-deployment.yaml |
| HPA (auto-scaling) | +2/20 | k8s/22-api-hpa.yaml |
| ArgoCD GitOps | +4/20 | k8s/60-argocd-application.yaml |
| MongoDB persistence | +2/20 | k8s/08-09-*.yaml |
| **Total** | **26/20** | All files |

---

**This is a self-contained project** - everything needed to deploy is here.  
All documentation and guides are in the parent `websiteAndMd/` folder.
