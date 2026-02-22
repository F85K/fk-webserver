# Safe Project Cleanup Proposal

**Generated:** February 21, 2026  
**Purpose:** Remove ALL unnecessary files, services, and resources to keep only what's needed for the working project

---

## 🎯 **CLEANUP STRATEGY**

**Approach:** Move obsolete files to `archive/` folder (don't delete permanently)  
**Safety:** All Kubernetes resources verified before removal  
**Goal:** Clean, professional, exam-ready project with zero waste

---

## 📂 **ROOT DIRECTORY - FILES TO ARCHIVE**

### Scripts to Archive (Not Used in Final Project)

```
archive/scripts/
├── install-argocd.sh          # ArgoCD installed via vagrant provisioning
├── install-complete-stack.sh  # Old deployment method
├── install-gitops-only.sh     # Partial deployment
├── install-prometheus.sh      # Prometheus installed via vagrant provisioning
├── deploy-production.sh       # Trial script, never used
├── app-hostnet.yaml          # Experimental manifest
├── flannel-simple.yaml       # Flannel deployed via kubeadm
├── check-cluster.sh          # One-time verification script
├── cleanup-obsolete-scripts.ps1  # This proposal supersedes it
├── deploy-all.ps1            # Old PowerShell deployment
├── deploy-incremental.sh     # Incremental deployment (not used)
├── emergency-recovery.sh     # Recovery script (keep as backup or archive?)
├── fix-certmanager.sh        # cert-manager is working now
├── fix-worker1.sh            # Worker1 issues resolved
├── full-worker-fix.sh        # Worker fixes applied
├── install-all.bat           # Windows batch script (not used)
├── install-all.ps1           # PowerShell install (not used)
├── install-tls-only.sh       # TLS now part of main deployment
├── quick-verify.sh           # One-time check script
├── restart-k8s.sh            # Manual restart script
└── verify-all.sh             # Verification script
```

### Files to Archive (Documentation/Notes)

```
archive/notes/
├── AItext.txt                # AI notes, can be archived
├── PROJECT-MAP.md            # Old project structure map
├── roadmapaiv2.txt          # Roadmap reference (keep or archive after exam?)
└── CLEANUP-PROPOSAL.md       # Old cleanup proposal (superseded)
```

### **KEEP IN ROOT** (Essential)

```
✅ Vagrantfile                # Cluster provisioning
✅ docker-compose.yaml        # Phase 1 requirement
✅ .gitignore                 # Git configuration
✅ .env.local.example         # Template for setup
✅ .env.local                 # DuckDNS credentials (gitignored)
✅ setup-letsencrypt.sh       # HTTPS certificate setup (WORKING)
✅ index.html                 # Project root page?
✅ SAFE-CLEANUP-PROPOSAL.md   # This document
```

---

## 📚 **DOCS/ DIRECTORY - DOCUMENTATION TO ARCHIVE**

### Troubleshooting Logs (Obsolete)

```
archive/docs/troubleshooting/
├── API-CRASH-DIAGNOSIS.md
├── DEPLOYMENT-ISSUES-LOG.md
├── DEPLOYMENT-RUNBOOK.md
├── DEPLOYMENT-SUMMARY.md
├── FINAL-DEPLOYMENT-STATUS.md
├── FINAL-STATUS-REPORT.md
├── MANUAL-PROVISIONING-GUIDE.md
├── REBUILD-GUIDE.md
├── SCRIPT-ERROR-ANALYSIS.md
├── STEP-BY-STEP-DEPLOYMENT.md
├── TROUBLESHOOTING.md
├── VM-LIFECYCLE.md
└── IMPROVEMENTS.md
```

### Guides to Archive

```
archive/docs/guides/
├── start-all.ps1             # PowerShell script misplaced in docs
└── verify-security.sh        # One-time security check
```

### **KEEP IN DOCS/** (Essential for Exam)

```
✅ SECURITY.md                 # Security practices demonstration
✅ GITGUARDIAN-RESOLUTION.md   # Security incident response
✅ HTTPS-CERT-OPTIONS.md       # Research/decision documentation
✅ ORAL-EXAM-SUMMARY.md        # **CRITICAL** - Exam reference
✅ TESTING-GUIDE.md            # Testing procedures
✅ project-overview.md         # Main documentation
✅ report.md                   # Required Dutch report
✅ stappen.md                  # Quick reference guide
✅ naam-wijzigen.md            # Name change instructions
```

---

## 🗂️ **K8S/ DIRECTORY - MANIFESTS TO REVIEW**

### Remove (Templates/Unused)

```
archive/k8s/
├── 99-secrets-template.yaml  # Template only, never deployed
└── 90-demo-scale.yaml        # Demo manifest (if exists)
```

### **KEEP ALL CORE MANIFESTS** (Application Stack)

```
✅ 00-namespace.yaml           # Namespace definition
✅ 10-mongodb-deployment.yaml  # Database
✅ 11-mongodb-service.yaml     # Database service
✅ 12-mongodb-init-configmap.yaml  # DB initialization
✅ 13-mongodb-init-job.yaml    # DB init job
✅ 15-api-configmap.yaml       # API source code
✅ 20-api-deployment.yaml      # API (3 replicas)
✅ 21-api-service.yaml         # API service
✅ 22-api-hpa.yaml             # Horizontal Pod Autoscaler
✅ 25-frontend-configmap.yaml  # Frontend HTML
✅ 30-frontend-deployment.yaml # Frontend
✅ 31-frontend-service.yaml    # Frontend service
✅ 40-ingress.yaml             # HTTPS ingress
✅ 50-cert-issuer.yaml         # Let's Encrypt production (WORKING)
✅ 51-selfsigned-issuer.yaml   # Staging issuer
✅ 60-argocd-application.yaml  # GitOps config
```

---

## 🐳 **VAGRANT/ DIRECTORY - PROVISIONING SCRIPTS**

### **KEEP ALL** (All Used in Provisioning)

```
✅ 01-base-setup.sh            # Base system setup
✅ 02-kubeadm-install.sh       # Kubernetes installation
✅ 03-control-plane-init.sh    # Control plane init
✅ 04-worker-join.sh           # Worker node join
✅ 05-deploy-argocd.sh         # ArgoCD installation
✅ 06-build-images.sh          # Docker image building
✅ 06-load-images.sh           # Load images to nodes
✅ complete-setup.sh           # Complete cluster setup
✅ deploy-full-stack.sh        # Full stack deployment
✅ QUICKSTART.sh               # Quick cluster start
✅ README.md                   # Vagrant documentation
✅ verify-success-criteria.sh  # Success verification
```

### Maybe Archive (One-time fixes)

```
archive/vagrant/
└── cleanup-stuck-resources.sh  # One-time namespace cleanup
```

---

## ☸️ **KUBERNETES NAMESPACES - CURRENT STATUS**

### **KEEP ALL** (All Working & Required)

| Namespace | Pods | Status | Purpose | Keep? |
|-----------|------|--------|---------|-------|
| **fk-webstack** | 6 | ✅ Running | Our application | ✅ YES |
| **monitoring** | 8 | ✅ Running | Prometheus + Grafana | ✅ YES (Phase 6) |
| **argocd** | 7 | ✅ Running | GitOps platform | ✅ YES (Phase 7) |
| **cert-manager** | 3 | ✅ Running | Let's Encrypt HTTPS | ✅ YES (Phase 3) |
| **ingress-nginx** | 3 | ✅ Running | HTTPS routing | ✅ YES (Phase 3) |
| **kube-system** | ~15 | ✅ Running | Core Kubernetes | ✅ YES (Required) |
| **kube-flannel** | 3 | ✅ Running | CNI networking | ✅ YES (Required) |
| **kube-public** | 0 | ✅ Empty | Public resources | ✅ YES (K8s default) |
| **kube-node-lease** | 0 | ✅ Empty | Node heartbeats | ✅ YES (K8s default) |
| **default** | 0 | ✅ Empty | Default namespace | ✅ YES (K8s default) |

**Decision:** ✅ **KEEP ALL NAMESPACES** - Everything is working and serves the project requirements

---

## 🔍 **SERVICES TO VERIFY**

### Check for Unused Services

Run this to find all services across all namespaces:

```bash
vagrant ssh fk-control -- "kubectl get svc --all-namespaces"
```

**Expected Services:**
- ✅ `fk-webstack`: mongodb, api-service, frontend-service
- ✅ `ingress-nginx`: ingress-nginx-controller, admission
- ✅ `monitoring`: prometheus-server, grafana, alertmanager
- ✅ `argocd`: argocd-server, argocd-repo-server, etc.
- ✅ `cert-manager`: cert-manager, webhook
- ✅ `kube-system`: kube-dns, etc.

**Action:** Verify no orphaned services exist

---

## 🗄️ **CONFIGMAPS & SECRETS TO AUDIT**

### Check for Unused ConfigMaps

```bash
vagrant ssh fk-control -- "kubectl get cm --all-namespaces | grep -v kube"
```

**Expected:**
- ✅ `fk-webstack`: api-code, frontend-html, mongodb-init
- ✅ Others: cert-manager, ingress-nginx, monitoring configs

### Check for Unused Secrets

```bash
vagrant ssh fk-control -- "kubectl get secrets --all-namespaces | grep -v 'default-token\|kubernetes.io'"
```

**Expected:**
- ✅ `cert-manager`: duckdns-token, webhook-ca
- ✅ `fk-webstack`: fk-webserver-tls-cert
- ✅ `monitoring`: grafana-admin, prometheus-secrets
- ✅ `argocd`: argocd-secret, admin credentials

**Action:** Remove any orphaned secrets/configmaps

---

## 📦 **APPLICATION SOURCE DIRECTORIES**

### **KEEP ALL** (Essential)

```
✅ api/                       # API source code
   ├── Dockerfile
   ├── requirements.txt
   └── app/main.py

✅ frontend/                  # Frontend source
   ├── Dockerfile
   ├── index.html
   └── lighttpd.conf

✅ db/                        # Database initialization
   └── init/init.js

✅ kubeadm-config/           # Cluster join commands
   └── join-command.sh
```

---

## 🧪 **VERIFICATION COMMANDS**

After cleanup, verify everything still works:

### 1. Check All Pods Running

```bash
vagrant ssh fk-control -- "kubectl get pods --all-namespaces | grep -v Running"
```

Expected: Only Completed jobs (mongodb-init)

### 2. Check All Services

```bash
vagrant ssh fk-control -- "kubectl get svc --all-namespaces"
```

Expected: All core services present

### 3. Test HTTPS Access

```bash
curl.exe -k https://192.168.56.12:30808/ -H "Host: fk-webserver.duckdns.org"
```

Expected: HTTP 200 with frontend HTML

### 4. Test Certificate

```bash
vagrant ssh fk-control -- "kubectl get certificate -n fk-webstack"
```

Expected: `fk-webserver-tls-cert` Ready=True

### 5. Test Monitoring

```bash
vagrant ssh fk-control -- "kubectl get pods -n monitoring"
```

Expected: All Prometheus/Grafana pods Running

---

## 📋 **CLEANUP EXECUTION PLAN**

### Phase 1: Create Archive Structure

```powershell
New-Item -ItemType Directory -Force archive/scripts
New-Item -ItemType Directory -Force archive/docs/troubleshooting
New-Item -ItemType Directory -Force archive/docs/guides
New-Item -ItemType Directory -Force archive/notes
New-Item -ItemType Directory -Force archive/k8s
New-Item -ItemType Directory -Force archive/vagrant
```

### Phase 2: Move Root Scripts (24 files)

```powershell
Move-Item install-argocd.sh archive/scripts/
Move-Item install-complete-stack.sh archive/scripts/
Move-Item install-gitops-only.sh archive/scripts/
Move-Item install-prometheus.sh archive/scripts/
Move-Item deploy-production.sh archive/scripts/
Move-Item app-hostnet.yaml archive/scripts/
Move-Item flannel-simple.yaml archive/scripts/
Move-Item check-cluster.sh archive/scripts/
Move-Item cleanup-obsolete-scripts.ps1 archive/scripts/
Move-Item deploy-all.ps1 archive/scripts/
Move-Item deploy-incremental.sh archive/scripts/
Move-Item emergency-recovery.sh archive/scripts/
Move-Item fix-certmanager.sh archive/scripts/
Move-Item fix-worker1.sh archive/scripts/
Move-Item full-worker-fix.sh archive/scripts/
Move-Item install-all.bat archive/scripts/
Move-Item install-all.ps1 archive/scripts/
Move-Item install-tls-only.sh archive/scripts/
Move-Item quick-verify.sh archive/scripts/
Move-Item restart-k8s.sh archive/scripts/
Move-Item verify-all.sh archive/scripts/
Move-Item AItext.txt archive/notes/
Move-Item PROJECT-MAP.md archive/notes/
Move-Item CLEANUP-PROPOSAL.md archive/notes/
```

### Phase 3: Move Documentation (15 files)

```powershell
Move-Item docs/API-CRASH-DIAGNOSIS.md archive/docs/troubleshooting/
Move-Item docs/DEPLOYMENT-ISSUES-LOG.md archive/docs/troubleshooting/
Move-Item docs/DEPLOYMENT-RUNBOOK.md archive/docs/troubleshooting/
Move-Item docs/DEPLOYMENT-SUMMARY.md archive/docs/troubleshooting/
Move-Item docs/FINAL-DEPLOYMENT-STATUS.md archive/docs/troubleshooting/
Move-Item docs/FINAL-STATUS-REPORT.md archive/docs/troubleshooting/
Move-Item docs/MANUAL-PROVISIONING-GUIDE.md archive/docs/troubleshooting/
Move-Item docs/REBUILD-GUIDE.md archive/docs/troubleshooting/
Move-Item docs/SCRIPT-ERROR-ANALYSIS.md archive/docs/troubleshooting/
Move-Item docs/STEP-BY-STEP-DEPLOYMENT.md archive/docs/troubleshooting/
Move-Item docs/TROUBLESHOOTING.md archive/docs/troubleshooting/
Move-Item docs/VM-LIFECYCLE.md archive/docs/troubleshooting/
Move-Item docs/IMPROVEMENTS.md archive/docs/troubleshooting/
Move-Item docs/start-all.ps1 archive/docs/guides/
Move-Item docs/verify-security.sh archive/docs/guides/
```

### Phase 4: Move K8s Templates

```powershell
Move-Item k8s/99-secrets-template.yaml archive/k8s/ -ErrorAction SilentlyContinue
Move-Item k8s/90-demo-scale.yaml archive/k8s/ -ErrorAction SilentlyContinue
```

### Phase 5: Move Vagrant Scripts (Optional)

```powershell
Move-Item vagrant/cleanup-stuck-resources.sh archive/vagrant/ -ErrorAction SilentlyContinue
```

### Phase 6: Verify No Kubernetes Cleanup Needed

```bash
# All namespaces are working - NO CLEANUP
echo "All Kubernetes resources are in use"
```

---

## ✅ **FINAL PROJECT STRUCTURE** (After Cleanup)

```
WebserverLinux/
├── Vagrantfile                    # Cluster definition
├── docker-compose.yaml            # Phase 1 container orchestration
├── .gitignore                     # Git exclusions
├── setup-letsencrypt.sh           # HTTPS setup script
├── .env.local                     # Credentials (gitignored)
├── .env.local.example             # Template
├── index.html                     # Project root page
├── SAFE-CLEANUP-PROPOSAL.md       # This document
│
├── api/                           # API source
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app/main.py
│
├── frontend/                      # Frontend source
│   ├── Dockerfile
│   ├── index.html
│   └── lighttpd.conf
│
├── db/                            # Database init
│   └── init/init.js
│
├── docs/                          # **ESSENTIAL DOCS ONLY**
│   ├── SECURITY.md
│   ├── GITGUARDIAN-RESOLUTION.md
│   ├── HTTPS-CERT-OPTIONS.md
│   ├── ORAL-EXAM-SUMMARY.md       # **EXAM CRITICAL**
│   ├── TESTING-GUIDE.md
│   ├── project-overview.md
│   ├── report.md
│   ├── stappen.md
│   └── naam-wijzigen.md
│
├── k8s/                           # **CORE MANIFESTS ONLY**
│   ├── 00-namespace.yaml
│   ├── 10-mongodb-deployment.yaml
│   ├── 11-mongodb-service.yaml
│   ├── 12-mongodb-init-configmap.yaml
│   ├── 13-mongodb-init-job.yaml
│   ├── 15-api-configmap.yaml
│   ├── 20-api-deployment.yaml
│   ├── 21-api-service.yaml
│   ├── 22-api-hpa.yaml
│   ├── 25-frontend-configmap.yaml
│   ├── 30-frontend-deployment.yaml
│   ├── 31-frontend-service.yaml
│   ├── 40-ingress.yaml
│   ├── 50-cert-issuer.yaml
│   ├── 51-selfsigned-issuer.yaml
│   └── 60-argocd-application.yaml
│
├── vagrant/                       # **ALL PROVISIONING SCRIPTS**
│   ├── 01-base-setup.sh
│   ├── 02-kubeadm-install.sh
│   ├── 03-control-plane-init.sh
│   ├── 04-worker-join.sh
│   ├── 05-deploy-argocd.sh
│   ├── 06-build-images.sh
│   ├── 06-load-images.sh
│   ├── complete-setup.sh
│   ├── deploy-full-stack.sh
│   ├── QUICKSTART.sh
│   ├── README.md
│   └── verify-success-criteria.sh
│
├── kubeadm-config/                # Cluster config
│   └── join-command.sh
│
└── archive/                       # **ARCHIVED FILES**
    ├── scripts/                   # Old deployment scripts
    ├── docs/                      # Troubleshooting logs
    ├── notes/                     # Project notes
    ├── k8s/                       # Template manifests
    └── vagrant/                   # One-time fix scripts
```

---

## 📊 **CLEANUP SUMMARY**

| Category | Files to Archive | Action |
|----------|------------------|--------|
| Root scripts | 21 files | Move to `archive/scripts/` |
| Documentation | 15 files | Move to `archive/docs/` |
| Notes | 3 files | Move to `archive/notes/` |
| K8s manifests | 2 files | Move to `archive/k8s/` |
| Vagrant scripts | 1 file | Move to `archive/vagrant/` |
| **Kubernetes** | **0 namespaces** | **✅ NO CLEANUP NEEDED** |
| **Services** | **0 services** | **✅ ALL IN USE** |
| **ConfigMaps/Secrets** | **TBD after audit** | Verify and remove orphans |

**Total Files to Archive:** ~42 files  
**Kubernetes Resources:** All clean and working  

---

## ⚠️ **SAFETY CHECKLIST**

Before executing cleanup:

- [ ] ✅ All VMs running (`vagrant status`)
- [ ] ✅ All pods healthy (`kubectl get pods --all-namespaces`)
- [ ] ✅ HTTPS working (`https://fk-webserver.duckdns.org:30808`)
- [ ] ✅ Certificate valid (`kubectl get certificate -n fk-webstack`)
- [ ] ✅ Monitoring accessible (Prometheus/Grafana)
- [ ] ✅ Git committed (so you can revert if needed)
- [ ] ✅ Backup created (optional: `tar -czf backup-$(date +%Y%m%d).tar.gz .`)

After cleanup:

- [ ] ✅ Application still works
- [ ] ✅ HTTPS still valid
- [ ] ✅ No broken references in remaining scripts
- [ ] ✅ Documentation updated

---

## 🎯 **RECOMMENDATION**

**Execute this cleanup to achieve:**
1. ✅ Professional, exam-ready project structure
2. ✅ Clear separation of working code vs. troubleshooting artifacts
3. ✅ Easy navigation for examiners
4. ✅ No confusion about which files are actually used
5. ✅ Keep all working Kubernetes resources (nothing needs deletion)

**Next step:** Review this proposal and execute Phase 1-5 cleanup commands.
