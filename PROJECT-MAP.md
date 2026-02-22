# FK Webstack - Project Organization Map

## Original Project (Docker Desktop)
**Status:** ✅ Complete on Docker Desktop

### Core Components
- **Frontend:** lighttpd (static HTML/JS) → serves index.html with fetch() call to API
- **API:** Python FastAPI + Uvicorn + PyMongo → REST endpoints, MongoDB queries
- **Database:** MongoDB 6+ → stores profile data (name: "Frank Koch")
- **Deployment:** Docker Compose (`docker-compose.yaml`)

---

## Current Phase: Kubernetes Migration with Vagrant
**Status:** 🔄 In Progress - Still on Step 1 of 4 features

### What We're Building
1. **3-Node Kubernetes Cluster** (kubeadm, Vagrant VMs, Flannel CNI)
   - 1 Control Plane (6GB RAM, 4 CPUs)
   - 2 Worker Nodes (3GB each, 2 CPUs each)
   - Run same 3 components (Frontend, API, MongoDB) as containerized pods

2. **Required Features to Add** (4 steps):
   - ✅ Step 1: Swap demo ingress to real API (STUCK - API pods CrashLoopBackOff)
   - ⏳ Step 2: Add healthchecks (blocked by Step 1)
   - ⏳ Step 3: Prometheus monitoring
   - ⏳ Step 4: ArgoCD + GitOps workflow

---

## File Organization - What to Keep ✅

### **KEEP - Core Project Files**
```
WebserverLinux/
├── Vagrantfile                 # 3-node cluster definition (WORKING)
│
├── api/                        # Source code (WORKING)
│   ├── Dockerfile              # Container image for API
│   ├── requirements.txt         # Python deps (fastapi, uvicorn, pymongo)
│   └── app/main.py             # FastAPI app (correct logic)
│
├── frontend/                   # Source code (WORKING)
│   ├── Dockerfile              # Container image for frontend
│   ├── lighttpd.conf           # Web server config
│   └── index.html              # Static HTML + fetch() to API
│
├── db/                         # Source code (WORKING)
│   └── init/
│       └── init.js             # MongoDB init script (sets name: "Frank Koch")
│
├── docker-compose.yaml         # Original setup (for reference)
│
├── k8s/                        # Kubernetes manifests (PARTIALLY WORKING)
│   ├── 00-namespace.yaml       # ✅ namespace
│   ├── 10-mongodb-deployment.yaml ✅
│   ├── 11-mongodb-service.yaml ✅
│   ├── 12-mongodb-init-configmap.yaml ✅
│   ├── 13-mongodb-init-job.yaml ✅
│   ├── 20-api-deployment.yaml  # ❌ BROKEN (pods CrashLoopBackOff)
│   ├── 21-api-service.yaml     # ✅
│   ├── 22-api-hpa.yaml         # ✅ (ready for Step 2)
│   ├── 30-frontend-deployment.yaml ✅
│   ├── 31-frontend-service.yaml ✅
│   ├── 40-ingress.yaml         # ✅ (but API backend down)
│   ├── 50-cert-issuer.yaml     # 📋 (for feature: HTTPS)
│   ├── 51-selfsigned-issuer.yaml # 📋 (for feature: HTTPS)
│   ├── 60-argocd-application.yaml # 📋 (for feature: GitOps)
│
├── vagrant/                    # Provisioning scripts (WORKING)
│   ├── 01-base-setup.sh        # ✅ Ubuntu packages, Docker, containerd
│   ├── 02-kubeadm-install.sh   # ✅ Kubernetes tooling
│   ├── 03-control-plane-init.sh # ✅ kubeadm init, Flannel CNI
│   ├── 04-worker-join.sh       # ✅ kubeadm join
│   ├── 05-deploy-argocd.sh     # 📋 (for feature: GitOps)
│   ├── 06-build-images.sh      # ⚠️ (needs review - Docker not stable on control)
│   └── README.md               # ✅
│
├── docs/                       # Documentation (REFERENCE)
│   ├── project-overview.md     # Complete project spec
│   ├── DEPLOYMENT-RUNBOOK.md   # Step-by-step manual deployment
│   ├── TROUBLESHOOTING.md      # Issues and solutions
│   └── *.md (other docs)       # Various guides
│
└── AItext.txt                  # Project assignment (REFERENCE)
```

---

## FILE ORGANIZATION - DELETE/ARCHIVE ❌

### **DELETE - Failed Attempts & Clutter**

#### Container Build Failures (many attempts):
```
build-and-distribute-images.sh          # ❌ Failed
build-images-and-push.sh                # ❌ Failed
deploy-with-nerdctl.sh                  # ❌ Failed
quick-deploy-on-control.sh              # ❌ Failed
setup-mongodb-api.sh                    # ❌ Failed
setup-real-api.sh                       # ❌ Failed
```
**Reason:** Control plane has no Docker daemon; containerd buildkit unstable; tried many workarounds

#### Multi-Script Deployment Confusion (overlapping attempts):
```
FINAL-DEPLOY.sh                         # ❌ Old attempt
MINIMAL-DEPLOY.sh                       # ❌ Old attempt
install-all.bat                         # ❌ Windows batch (abandoned)
install-all.ps1                         # ❌ PowerShell (abandoned)
install-stack.sh                        # ❌ Old shell attempt
deploy-all.ps1                          # ❌ PowerShell (abandoned)
deploy-incremental.sh                   # ❌ Incomplete
deploy-production.sh                    # ❌ Never used
deploy-direct-python.sh                 # ❌ Failed
```
**Reason:** Too many overlapping approaches; kept restarting from scratch

#### Puppet Installation (unnecessary complexity):
```
puppet/                                 # ❌ Entire folder (unused)
install-puppet-server.sh                # ❌ Not needed
install-puppet-agent.sh                 # ❌ Not needed
deploy-puppet-cluster.sh                # ❌ Not needed
sign-puppet-certs.sh                    # ❌ Not needed
PUPPET-GUIDE.md                         # ❌ Not needed
PUPPET-INSTALLATION-SUMMARY.md          # ❌ Not needed
```
**Reason:** Kubernetes is sufficient config management; Puppet overkill

#### Misc Failed/Abandoned Scripts:
```
check-cluster.sh                        # ❌ Incomplete
cleanup-obsolete-scripts.ps1            # ❌ Hasn't been run
emergency-recovery.sh                   # ❌ Never worked
fix-certmanager.sh                      # ❌ Incomplete
fix-worker1.sh                          # ❌ One-off workaround
full-worker-fix.sh                      # ❌ One-off workaround
flannel-simple.yaml                     # ❌ Old (Flannel now working)
apply-hostnet-stack.sh                  # ❌ Old (hostnet abandoned)
app-hostnet.yaml                        # ❌ Old (hostnet abandoned)
app-stack-control-plane.yaml            # ❌ Old attempt
simple-app-deploy.sh                    # ❌ Old demo
restart-k8s.sh                          # ❌ Incomplete
verify-all.sh                           # ⚠️ Might be useful but old
quick-verify.sh                         # ⚠️ Might be useful but old
```

#### Local Testing Scripts (not for K8s):
```
simple-web-server.py                    # ❌ Local testing
api-dual-server.py                      # ❌ Local testing
api-https-server.py                     # ❌ Local testing
api-mongodb-server.py                   # ❌ Local testing
init-mongodb.py                         # ❌ Local testing
quick-start-api.sh                      # ❌ Local testing
```
**Reason:** These are for Docker Desktop testing, not Kubernetes

#### Deployment Logs:
```
vagrant_deployment.log                  # ❌ Old logs
vagrant_deployment2.log                 # ❌ Old logs
vagrant_deployment3.log                 # ❌ Old logs
vagrant_deployment4.log                 # ❌ Old logs
```
**Reason:** Stale; superseded by new provisioning

#### Old/Incomplete Documentation:
```
README-TOMORROW.md                      # ❌ Incomplete stub
PUPPET-GUIDE.md                         # ❌ Not needed
PUPPET-INSTALLATION-SUMMARY.md          # ❌ Not needed
```

#### Kubernetes Attempts (failed approaches):
```
00-namespace.yaml (kept early, now stale) # ⚠️ Check if still needed
kubeadm-config/join-command.sh          # ⚠️ Auto-generated, can be regenerated
```

#### Git/Config Files (housekeeping):
```
.git/                                   # 🔧 Git history (keep, but not project-critical)
.github/                                # ⚠️ Check if used
.env.local.example                      # ⚠️ Check if needed
kubeconfig.yaml                         # 🔧 Remove - should be in ~/.kube/config
server.crt, server.key                  # 🔧 Old certs (new ones generated by cert-manager)
```

---

## Current Reality Check

### What's Actually Working ✅
- Vagrant cluster booting (3 VMs ready, networking OK)
- Flannel CNI networking (pods can reach each other)
- CoreDNS (DNS resolution working)
- NGINX Ingress Controller (accepting traffic on port 32685)
- MongoDB pod (1/1 Ready, test data inserted)
- Frontend pod (1/1 Ready, serving HTML on http://localhost/)
- Demo scaling app proved cross-node distribution works

### What's Broken ❌
- **API Deployment:** Pods stuck in CrashLoopBackOff
  - **Root Cause:** ConfigMap YAML formatting corrupts requirements.txt file
  - **Impact:** pip install fails, container never reaches Ready state
  - **Blocker:** Step 1 (swap demo to real API)

---

## Recommended Cleanup Strategy

### Phase 1: Immediate Cleanup
1. **Archive failed scripts** → Move to `_archive/` folder
2. **Delete Puppet** → `rm -rf puppet install-puppet-*.sh PUPPET-*.md`
3. **Delete local testing scripts** → Remove `*-server.py`, `init-mongodb.py`
4. **Delete old logs** → Remove `vagrant_deployment*.log`

### Phase 2: Get Current Phase Working
1. **Fix Step 1:** Repair API deployment (ConfigMap issue)
   - Either: Fix ConfigMap text formatting
   - Or: Rebuild approach (pre-build images, push to registry)
2. **Test full stack:** Frontend ↔ API ↔ MongoDB

### Phase 3: Add Features
1. **Step 2:** Healthchecks (already in manifests, just enable)
2. **Step 3:** Prometheus (install + create scrape targets)
3. **Step 4:** ArgoCD (install + create Application)

---

## Quick Summary Table

| Component | Status | Location | Next Action |
|-----------|--------|----------|------------|
| **VMs (Vagrant)** | ✅ Working | Vagrantfile | None - ready |
| **Kubernetes (kubeadm)** | ✅ Working | vagrant/0*.sh | None - ready |
| **Flannel CNI** | ✅ Working | vagrant/03-*.sh | None - ready |
| **MongoDB** | ✅ Working | k8s/10-13-*.yaml | None - ready for data |
| **Frontend (nginx)** | ✅ Working | k8s/30-31-*.yaml + frontend/ | None - ready |
| **Ingress (NGINX)** | ✅ Working | k8s/40-ingress.yaml | Waiting for API |
| **API (FastAPI)** | ❌ Broken | k8s/20-21-*.yaml + api/ | 🔴 FIX: ConfigMap corruption |
| **Healthchecks** | 📋 Partial | k8s/20-*.yaml (has probes) | Enable once API works |
| **HPA** | 📋 Ready | k8s/22-api-hpa.yaml | Deploy after Step 1 |
| **HTTPS/certs** | 📋 Ready | k8s/50-51-*.yaml | Deploy for Step 3 |
| **Prometheus** | 📋 Planned | vagrant/05-*.sh | Deploy for Step 3 |
| **ArgoCD** | 📋 Planned | vagrant/05-*.sh + k8s/60-*.yaml | Deploy for Step 4 |

---

## Files You Can Delete Right Now

Copy-paste to delete from Windows PowerShell in workspace:

```powershell
# Remove failed build scripts
rm -Force build-and-distribute-images.sh, build-images-and-push.sh, deploy-with-nerdctl.sh
rm -Force quick-deploy-on-control.sh, setup-*.sh, deploy-direct-python.sh, deploy-production.sh

# Remove deployment confusion (use DEPLOYMENT-RUNBOOK.md instead)
rm -Force FINAL-DEPLOY.sh, MINIMAL-DEPLOY.sh, install-all.*, deploy-all.ps1, deploy-incremental.sh

# Remove Puppet
rm -Recurse -Force puppet/
rm -Force install-puppet-*.sh, deploy-puppet-cluster.sh, sign-puppet-certs.sh, PUPPET-*.md

# Remove local testing scripts (not for K8s)
rm -Force *-server.py, init-mongodb.py, quick-start-api.sh

# Remove old logs
rm -Force vagrant_deployment*.log

# Clean up old Kubernetes attempts
rm -Force flannel-simple.yaml, apply-hostnet-stack.sh, app-hostnet.yaml, app-stack-control-plane.yaml
rm -Force simple-app-deploy.sh, restart-k8s.sh, check-cluster.sh, emergency-recovery.sh, fix-*.sh

# Optional: old cert files (new ones from cert-manager)
rm -Force server.crt, server.key

# Optional: Misc stubs
rm -Force README-TOMORROW.md, .env.local.example
```

After cleanup, workspace will have only **what you actually need** for the Kubernetes migration.
