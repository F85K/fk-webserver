# 🚀 FK Webstack - Quick Start Guide

**⏱️ Total time: 45-60 minutes**

---

## Phase 1️⃣: Create Kubernetes Cluster (25 min)

```powershell
cd CleanWebserver
vagrant up
```

**What happens:**
- Creates 3 VMs (fk-control, fk-worker1, fk-worker2)
- Installs Docker, Kubernetes, Flannel CNI
- Initializes cluster automatically
- All nodes should be "Ready"

**Verify:**
```bash
vagrant ssh fk-control -c "kubectl get nodes"
# Expected output: 3 nodes all Ready
```

---

## Phase 2️⃣: Deploy Application (5 min)

```powershell
# Using helper script (recommended)
.\deploy.ps1 -Action deploy

# OR manually:
vagrant ssh fk-control -c "kubectl apply -f /vagrant/kubernetes/manifests.yaml"
```

**What happens:**
- Deploys MongoDB, API (2 replicas), Frontend
- Sets up services for internal communication
- Configures health checks and auto-scaling

**Verify:**
```bash
vagrant ssh fk-control -c "kubectl get pods -n fk-webstack"
# Expected: MongoDB, 2x API, 1x Frontend all Running
```

---

## Phase 3️⃣: Test Frontend (5 min)

**Terminal 1 - Port-forward frontend:**
```bash
vagrant ssh fk-control -c "kubectl port-forward -n fk-webstack svc/fk-frontend 8080:80"
```

**Terminal 2 - Open browser:**
```
http://localhost:8080
```

**You should see:**
- ✅ "Frank Koch has reached milestone 2!"
- ✅ Container ID (API pod name)
- ✅ Last updated timestamp
- ✅ Auto-refresh every 5 seconds

---

## Phase 4️⃣: Test API (5 min)

**Terminal 1 - Port-forward API:**
```bash
vagrant ssh fk-control -c "kubectl port-forward -n fk-webstack svc/fk-api 8000:8000"
```

**Terminal 2 - Test endpoints:**
```bash
# Get student name
curl http://localhost:8000/api/name
# Output: {"name":"Frank Koch"}

# Get container ID (pod name)
curl http://localhost:8000/api/container-id
# Output: {"container_id":"fk-api-xxxxx"}

# Health check
curl http://localhost:8000/health
# Output: {"status":"ok","service":"fk-api"}
```

---

## 📊 Using Helper Script

```powershell
# Show status
.\deploy.ps1 -Action status

# View logs
.\deploy.ps1 -Action logs

# Scale to 4 replicas
.\deploy.ps1 -Action scale -Replicas 4

# Scale to 2 replicas
.\deploy.ps1 -Action scale -Replicas 2

# Destroy (WARNING: deletes everything)
.\deploy.ps1 -Action destroy
```

---

## ✅ Success Checklist

- [ ] `kubectl get nodes` shows 3 Ready nodes
- [ ] `kubectl get pods -n fk-webstack` shows all Running
- [ ] Frontend displays "Frank Koch has reached milestone 2!"
- [ ] Frontend auto-refreshes every 5 seconds
- [ ] API /api/name returns student name
- [ ] API /api/container-id returns pod name
- [ ] Health endpoint responds with {"status":"ok"}

---

## 🆘 Troubleshooting

**Problem: Pods in ImagePullBackOff**
```bash
vagrant ssh fk-control
cd /vagrant

# Build images inside VMs
docker build -t fk-api:1.0 ./containers/api
docker build -t fk-frontend:1.0 ./containers/frontend

# Redeploy
kubectl delete -f kubernetes/manifests.yaml
kubectl apply -f kubernetes/manifests.yaml
```

**Problem: API can't connect to MongoDB**
```bash
# Check MongoDB is running
vagrant ssh fk-control -c "kubectl get pods -n fk-webstack | grep mongo"

# Check logs
vagrant ssh fk-control -c "kubectl logs -n fk-webstack -l app=fk-mongodb"

# Wait a bit (first start takes time)
sleep 30
```

**Problem: Port-forward hangs**
- Make sure kubectl is connected to cluster
- Try: `vagrant ssh fk-control -c "kubectl version"`
- If stuck, press Ctrl+C and try again

**Problem: Cluster is broken**
```bash
vagrant destroy -f
vagrant up
```

---

## 📚 Next Steps

### Test Auto-scaling (HPA)
```bash
vagrant ssh fk-control -c "kubectl port-forward -n fk-webstack svc/fk-api 8000:8000" &
sleep 3

# Generate load
vagrant ssh fk-control -c "kubectl run load-gen -n fk-webstack --image=busybox -- /bin/sh -c 'while true; do wget -q -O- http://fk-api:8000/api/name; done'" &
sleep 5

# Watch scaling
vagrant ssh fk-control -c "kubectl get hpa -n fk-webstack --watch"
```

### Install Advanced Features
See [ROADMAP.md](ROADMAP.md) Phase 6 for:
- ✅ HTTPS with cert-manager
- ✅ Prometheus monitoring
- ✅ ArgoCD GitOps

### View All Documentation
- [README.md](README.md) - Project overview
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Master reference
- [ROADMAP.md](ROADMAP.md) - Detailed setup guide

---

**Ready?** Run: `vagrant up`

**Questions?** See [README.md](README.md) and [ROADMAP.md](ROADMAP.md)
