# FK Webstack - Complete Documentation Index

**Project:** 3-Tier Kubernetes Application (lighttpd + FastAPI + MongoDB)  
**Status:** Fully functional 20/20+ points implementation  
**Last Updated:** February 22, 2026

---

## 📚 Documentation Structure

This index maps all documentation files and guides you to what you need based on your task.

---

## 🚀 Quick Start Navigation

| Task | See These Docs | Time |
|------|---|---|
| **1st time setup** | [DOCKER-STACK-MANUAL.md](#docker-stack-manual) + [KUBEADM-MIGRATION.md](#kubeadm-migration) | 30-45 min |
| **Understand cluster** | [KUBEADM-MIGRATION-MANUAL.md](#kubeadm-migration-manual) (detailed) | 60 min |
| **Use the application** | [ASSIGNMENT-GUIDE.md](#assignment-guide) | 5 min |
| **Debug issues** | [Troubleshooting Section](#troubleshooting) | 5-15 min |
| **Run all commands** | [VAGRANT-K8S-COMMANDS.md](#vagrant-k8s-commands-reference) | Reference |
| **Deploy extras** (HTTPS/ArgoCD/Prometheus) | [HELM-ARGOCD-PROMETHEUS.md](#helm-argocd-prometheus) + [NETWORKING-DUCKDNS-CERTMANAGER.md](#networking-duckdns-certmanager) | 30 min each |
| **Verify health** | [HEALTHCHECK-VERIFICATION.md](#healthcheck-verification) | 10 min |
| **Exam preparation** | docs/ORAL-EXAM-SUMMARY.md | 60 min |

---

## 📖 Core Documentation Files

### 1. **ASSIGNMENT-GUIDE.md** {#assignment-guide}
**Purpose:** How to use the application and interact with it  
**Contents:**
- Architecture overview (Frontend, API, Database)
- Accessing the application (domain, IP, port-forward)
- API endpoints reference (/api/name, /api/container-id, /health)
- Changing MongoDB name values
- Verification steps

**When to use:** You want to see the app working or change the name  
**Links to:** Testing, API understanding

---

### 2. **DOCKER-STACK-MANUAL.md** {#docker-stack-manual}
**Purpose:** Pre-Kubernetes baseline - how the app works in Docker  
**Contents:**
- Project components (Frontend, API, Database)
- Manual Docker setup (Docker Desktop)
- File-by-file contents:
  - frontend/index.html (HTML + fetch calls)
  - api/main.py (FastAPI code)
  - db/init.js (MongoDB initialization)
- Running the stack with docker-compose
- Verification & testing
- Assignment requirements baseline (10/20 points)

**When to use:** You're starting from scratch or want to understand the baseline  
**Links to:** KUBEADM-MIGRATION.md (next step after Docker works)

---

### 3. **KUBEADM-MIGRATION.md** {#kubeadm-migration}
**Purpose:** Complete Docker→Kubernetes migration path with actual commands  
**Contents:**
- Phase 0: Docker baseline verification
- Phase 1: Infrastructure setup (Vagrant VMs, node prep)
- Phase 2: Control plane initialization (kubeadm init)
- Phase 3: Worker node setup (kubeadm join)
- Phase 4: CNI installation (Flannel vxlan)
- Phase 5: Security configuration (RBAC, certificates, firewall)
- Phase 6: Application deployment (k8s manifests)
- Verification steps (cluster health, networking, security)
- Troubleshooting (Node NotReady, Pod issues, Flannel problems)

**When to use:** You're migrating from Docker or setting up from scratch  
**Links to:** KUBEADM-MIGRATION-MANUAL.md (if you want extreme detail)

---

### 4. **KUBEADM-MIGRATION-MANUAL.md** {#kubeadm-migration-manual}
**Purpose:** Ultra-detailed step-by-step migration with explanations  
**Contents:**
- 1380 lines of comprehensive detail
- Why Kubernetes vs Docker
- Architecture diagrams
- Every command with explanation
- Network setup diagrams
- Certificate generation explained
- RBAC explained
- Security architecture
- Extensive troubleshooting

**When to use:** You want to understand EVERY detail before running commands  
**Links to:** KUBEADM-MIGRATION.md (condensed version)

---

### 5. **HEALTHCHECK-VERIFICATION.md** {#healthcheck-verification}
**Purpose:** How healthchecks work and how to verify them  
**Contents:**
- Liveness probe configuration (restarts failed pods)
- Readiness probe configuration (shields unhealthy pods)
- Startup probe configuration (gives apps time to start)
- Testing probes manually
- Monitoring probe results
- Troubleshooting probe failures

**When to use:** Pods are crashing or you want to understand auto-restart  
**Links to:** TROUBLESHOOTING (in docs/)

---

### 6. **NETWORKING-DUCKDNS-CERTMANAGER.md** {#networking-duckdns-certmanager}
**Purpose:** HTTPS setup with Let's Encrypt (extra 2/20 points)  
**Contents:**
- DuckDNS setup (dynamic DNS service)
- cert-manager installation
- Certificate issuers (self-signed, production Let's Encrypt)
- Ingress configuration with TLS
- Local-only networking explanation
- Port-forward vs Ingress
- Troubleshooting certificate issues

**When to use:** You want HTTPS/SSL, or you want to understand HTTPS setup  
**Links to:** HELM-ARGOCD-PROMETHEUS.md, docs/HTTPS-CERT-OPTIONS.md

---

### 7. **HELM-ARGOCD-PROMETHEUS.md** {#helm-argocd-prometheus}
**Purpose:** Advanced features - GitOps + Monitoring (extra 6/20 points)  
**Contents:**
- Helm chart basics
- ArgoCD installation & configuration
- GitOps workflow explanation
- Prometheus installation & metrics
- ServiceMonitors for monitoring
- Grafana dashboard access
- Verifying all components

**When to use:** You want GitOps + monitoring, or deploying at scale  
**Links to:** docs/ORAL-EXAM-SUMMARY.md (see demo scripts)

---

### 8. **VAGRANT-K8S-COMMANDS.md** {#vagrant-k8s-commands-reference}
**Purpose:** Command reference - Vagrant, kubectl, Linux  
**Contents:**
- Vagrant commands (up, destroy, ssh, etc.)
- kubectl commands (get, describe, apply, delete, logs, exec, etc.)
- Linux commands useful in VMs
- Debugging commands
- Port-forward commands
- Troubleshooting commands

**When to use:** You need a command and don't remember the syntax  
**Links to:** Every other guide (referenced for commands)

---

## 📁 Project Files & Folders

```
WebserverLinux/
│
├── Vagrantfile                          # VM definitions (3 nodes)
├── docker-compose.yaml                  # Phase 1: Docker-only setup
├── .env.local                           # DuckDNS credentials
│
├── api/                                 # API source code
│   ├── Dockerfile
│   ├── requirements.txt                 # FastAPI dependencies
│   └── app/main.py                      # FastAPI endpoints
│
├── frontend/                            # Frontend web app
│   ├── Dockerfile
│   ├── index.html                       # Static HTML + JavaScript
│   └── lighttpd.conf                    # Web server config
│
├── db/                                  # Database init
│   └── init/init.js                     # MongoDB initialization
│
├── k8s/                                 # Kubernetes manifests (20 files)
│   ├── 00-namespace.yaml                # fk-webstack namespace
│   ├── 10-15-*mongodb*.yaml             # MongoDB deployment
│   ├── 20-21-*api*.yaml                 # API deployment + service
│   ├── 25-30-*frontend*.yaml            # Frontend deployment
│   ├── 40-ingress.yaml                  # Ingress for HTTPS
│   ├── 50-*-cert-issuer.yaml            # cert-manager issuers
│   └── 60-*.yaml                        # ArgoCD application
│
├── vagrant/                             # Provisioning scripts
│   ├── README.md                        # Setup guide
│   ├── QUICKSTART.sh                    # Quick reference
│   ├── 01-base-setup.sh                 # Docker + kernel prep
│   ├── 02-kubeadm-install.sh            # kubeadm tools
│   ├── 03-control-plane-init.sh         # Control plane init
│   ├── 04-worker-join.sh                # Worker join
│   ├── 05-deploy-argocd.sh              # ArgoCD deployment
│   └── 06-*.sh                          # Build & load images
│
├── docs/                                # Documentation archive
│   ├── project-overview.md              # Main reference (550+ lines)
│   ├── ORAL-EXAM-SUMMARY.md             # Exam prep guide
│   ├── IMPROVEMENTS.md                  # Changes made
│   ├── TROUBLESHOOTING.md               # Common issues
│   ├── TESTING-GUIDE.md                 # Testing procedures
│   ├── report.md                        # Required assignment report
│   ├── stappen.md                       # Dutch quickstart
│   ├── naam-wijzigen.md                 # Change name guide
│   ├── SECURITY.md                      # Security practices
│   ├── GITGUARDIAN-RESOLUTION.md        # Security incident
│   ├── HTTPS-CERT-OPTIONS.md            # Research notes
│   └── (other troubleshooting files)
│
├── README files in root:
│   ├── INDEX.md                         # ← YOU ARE HERE
│   ├── ASSIGNMENT-GUIDE.md              # ← Using the app
│   ├── DOCKER-STACK-MANUAL.md           # ← Pre-K8s baseline
│   ├── HEALTHCHECK-VERIFICATION.md      # ← Health probes
│   ├── HELM-ARGOCD-PROMETHEUS.md        # ← Advanced features
│   ├── KUBEADM-MIGRATION.md             # ← Migration path
│   ├── KUBEADM-MIGRATION-MANUAL.md      # ← Detailed migration
│   ├── NETWORKING-DUCKDNS-CERTMANAGER.md # ← HTTPS setup
│   ├── VAGRANT-K8S-COMMANDS.md          # ← Command reference
│   ├── PROJECT-MAP.md                   # Structure overview
│   └── SAFE-CLEANUP-PROPOSAL.md         # Cleanup checklist
```

---

## 🎯 Common Tasks & Where to Find Them

### Task: "I want to start from zero"
1. Read: [DOCKER-STACK-MANUAL.md](#docker-stack-manual) (understand baseline)
2. Follow: [KUBEADM-MIGRATION.md](#kubeadm-migration) (6 phases)
3. Reference: [VAGRANT-K8S-COMMANDS.md](#vagrant-k8s-commands-reference) for commands
4. Verify: [HEALTHCHECK-VERIFICATION.md](#healthcheck-verification)

**Time:** 45-60 minutes including setup

---

### Task: "The app isn't working"
1. Check: docs/TROUBLESHOOTING.md (7 common issues)
2. Reference: [VAGRANT-K8S-COMMANDS.md](#vagrant-k8s-commands-reference) for debugging
3. Describe: `kubectl describe pod [pod-name]`
4. Logs: `kubectl logs [pod-name]`

---

### Task: "I want to use HTTPS"
1. Setup DuckDNS: [NETWORKING-DUCKDNS-CERTMANAGER.md](#networking-duckdns-certmanager) Part 1
2. Install cert-manager: Part 2 of same doc
3. Configure Ingress: Part 3
4. Test: Part 4

**Time:** 20-30 minutes

---

### Task: "I want GitOps + Monitoring"
1. Install Helm: [HELM-ARGOCD-PROMETHEUS.md](#helm-argocd-prometheus) Step 1
2. Install ArgoCD: Step 2-4
3. Install Prometheus: Step 5-7
4. Verify: Step 8

**Time:** 30-45 minutes

---

### Task: "I need to understand RBAC/Security"
1. Overview: [KUBEADM-MIGRATION-MANUAL.md](#kubeadm-migration-manual) (search "RBAC" or "Security")
2. Details: docs/SECURITY.md
3. Implementation: [KUBEADM-MIGRATION.md](#kubeadm-migration) Phase 5

---

### Task: "I need to change the app name in MongoDB"
1. Simple way: [ASSIGNMENT-GUIDE.md](#assignment-guide) "Changing MongoDB Values"
2. Manual way: `kubectl exec -it mongodb-pod -- mongosh`
3. Verify: API returns new name via `/api/name`

---

### Task: "I need to scale the API"
1. Automatic: Edit k8s/22-api-hpa.yaml (Horizontal Pod Autoscaler)
2. Manual: `kubectl scale deployment fk-api --replicas=5`
3. Verify: `kubectl get pods -n fk-webstack`

---

### Task: "I'm preparing for oral exam"
1. Main reference: docs/ORAL-EXAM-SUMMARY.md (730+ lines, everything!)
2. Demo script: See bottom of ORAL-EXAM-SUMMARY.md
3. Key points: "Key Points for Oral Defense" section
4. Common questions: "Common Questions & Troubleshooting" section

---

## ✅ Documentation Coverage - What's Documented

| Topic | Documentation | Status |
|-------|---|---|
| **Phase 1: Docker baseline** | DOCKER-STACK-MANUAL.md | ✅ Complete |
| **Phase 2: Vagrant VMs** | KUBEADM-MIGRATION*.md | ✅ Complete |
| **Phase 3: kubeadm control plane** | KUBEADM-MIGRATION*.md | ✅ Complete |
| **Phase 4: kubeadm workers** | KUBEADM-MIGRATION*.md | ✅ Complete |
| **Phase 5: Flannel networking** | KUBEADM-MIGRATION*.md | ✅ Complete |
| **Phase 6: App deployment** | DOCKER-STACK-MANUAL.md (files) + k8s/ | ✅ Complete |
| **API endpoints** | ASSIGNMENT-GUIDE.md | ✅ Complete |
| **Healthchecks** | HEALTHCHECK-VERIFICATION.md | ✅ Complete |
| **HTTPS/TLS** | NETWORKING-DUCKDNS-CERTMANAGER.md | ✅ Complete |
| **GitOps/ArgoCD** | HELM-ARGOCD-PROMETHEUS.md | ✅ Complete |
| **Monitoring/Prometheus** | HELM-ARGOCD-PROMETHEUS.md | ✅ Complete |
| **Commands reference** | VAGRANT-K8S-COMMANDS.md | ✅ Complete |
| **Troubleshooting** | docs/TROUBLESHOOTING.md | ✅ Complete |
| **Exam preparation** | docs/ORAL-EXAM-SUMMARY.md | ✅ Complete |
| **Security** | docs/SECURITY.md | ✅ Complete |
| **Testing** | docs/TESTING-GUIDE.md | ✅ Complete |

---

## 🔗 Cross-References

### Reading Order (Recommended)

**For Complete Understanding:**
1. This INDEX.md (you are here)
2. DOCKER-STACK-MANUAL.md (understand baseline)
3. KUBEADM-MIGRATION.md (see execution path)
4. ASSIGNMENT-GUIDE.md (use the app)
5. VAGRANT-K8S-COMMANDS.md (reference as needed)
6. HEALTHCHECK-VERIFICATION.md (understand resilience)
7. NETWORKING-DUCKDNS-CERTMANAGER.md (add HTTPS)
8. HELM-ARGOCD-PROMETHEUS.md (add monitoring)

**For Quick Setup:**
1. KUBEADM-MIGRATION.md (follow 6 phases)
2. ASSIGNMENT-GUIDE.md (test it works)
3. VAGRANT-K8S-COMMANDS.md (keep handy)

**For Troubleshooting:**
1. docs/TROUBLESHOOTING.md (common issues)
2. VAGRANT-K8S-COMMANDS.md (debugging commands)
3. KUBEADM-MIGRATION*.md Phase 5 (security check)

---

## 🐛 Troubleshooting Quick Links

**Problem** → **Solution Location**

| Issue | Doc | Section |
|-------|-----|---------|
| Nodes NotReady | docs/TROUBLING.md | Node status |
| Pods pending | docs/TROUBLING.md | Pod scheduling |
| API not responding | ASSIGNMENT-GUIDE.md | API endpoints |
| HTTPS not working | NETWORKING-DUCKDNS-CERTMANAGER.md | Troubleshooting |
| ArgoCD not syncing | HELM-ARGOCD-PROMETHEUS.md | ArgoCD issues |
| Prometheus down | HELM-ARGOCD-PROMETHEUS.md | Prometheus resources |
| Connection timeouts | VAGRANT-K8S-COMMANDS.md | Port-forward |

---

## 📊 Statistics

| Metric | Value |
|--------|-------|
| **Total documentation** | 8 root .md files (5,280+ lines) |
| **Plus docs/ folder** | 15+ additional guides |
| **Setup time** | 45-60 minutes |
| **Cluster size** | 3 nodes (1 control + 2 workers) |
| **Container runtime** | containerd v2.2.1 |
| **Kubernetes version** | v1.35.0 (control) + v1.35.1 (workers) |
| **CNI** | Flannel v0.20.3 (vxlan backend) |
| **Network** | 10.244.0.0/16 pods, 10.96.0.0/12 services |
| **Assignment points** | 20/20 base + 6 extras (26/20 possible) |

---

## 🎓 Learning Outcomes

After reading all documentation, you will understand:

- ✅ Docker Compose baseline (5/20 points)
- ✅ Kubernetes architecture on kubeadm
- ✅ Cluster networking (Flannel, node-to-pod, pod-to-pod)
- ✅ Certificate management (RBAC, service accounts, kubelet certs)
- ✅ Application deployment (Manifests, ConfigMaps, Services)
- ✅ High availability (Healthchecks, HPA, multiple replicas)
- ✅ HTTPS/TLS (cert-manager, Let's Encrypt)
- ✅ GitOps (ArgoCD, Git-driven deployments)
- ✅ Monitoring (Prometheus, Grafana, ServiceMonitors)
- ✅ Troubleshooting (Debugging techniques, common issues)

---

## 📝 Document Versions

- **INDEX.md**: v1 (Feb 22, 2026)
- **KUBEADM-MIGRATION.md**: v2 (829 lines, verified against running cluster)
- **KUBEADM-MIGRATION-MANUAL.md**: v1 (1380 lines, ultra-detailed)
- **All others**: Current as of Feb 22, 2026

---

## 🔐 Important Notes

### Local-Only Network
- ⚠️ This cluster is **LOCAL-ONLY** (no external internet access)
- ✅ All components work perfectly on private network
- ✅ DuckDNS resolves to your `kubectl port-forward` setup
- ✅ Perfect for development/testing
- ℹ️ For production, remove port-forward and expose directly

### Security
- ✅ RBAC is enabled (role-based access control)
- ✅ All certificates are automatic (kubeadm + cert-manager)
- ✅ Service accounts are isolated (Kubernetes default)
- ✅ No NetworkPolicies by default (all pods can talk to each other)

### Persistence
- ✅ MongoDB data persists via PersistentVolume
- ✅ ConfigMaps for API code & frontend HTML
- ✅ All data survives pod restarts

---

## 📞 Getting Help

1. **Quick question?** → Check [VAGRANT-K8S-COMMANDS.md](#vagrant-k8s-commands-reference)
2. **Lost?** → Start at [Quick Start Navigation](#quick-start-navigation)
3. **Troubleshooting?** → See [Troubleshooting Quick Links](#troubleshooting-quick-links)
4. **Exam prep?** → Go to docs/ORAL-EXAM-SUMMARY.md

---

## ✨ Next Steps After Setup

Once your cluster is running, consider:

1. **Add NetworkPolicies** - Restrict pod-to-pod traffic
2. **Backup strategy** - automated PersistentVolume snapshots
3. **Resource quotas** - Limit CPU/memory per namespace
4. **Pod Disruption Budget** - Protect app during updates
5. **Custom dashboards** - Prometheus + Grafana graphs
6. **Log aggregation** - ELK or Loki setup
7. **Registry mirror** - Speed up image pulls

---

**Document created:** February 22, 2026  
**For:** FK Webstack Kubernetes Project  
**Status:** ✅ Complete & Verified

---

## Quick Links to All Root Docs

- [INDEX.md](INDEX.md) ← You are here
- [ASSIGNMENT-GUIDE.md](ASSIGNMENT-GUIDE.md)
- [DOCKER-STACK-MANUAL.md](DOCKER-STACK-MANUAL.md)
- [HEALTHCHECK-VERIFICATION.md](HEALTHCHECK-VERIFICATION.md)
- [HELM-ARGOCD-PROMETHEUS.md](HELM-ARGOCD-PROMETHEUS.md)
- [KUBEADM-MIGRATION.md](KUBEADM-MIGRATION.md)
- [KUBEADM-MIGRATION-MANUAL.md](KUBEADM-MIGRATION-MANUAL.md)
- [NETWORKING-DUCKDNS-CERTMANAGER.md](NETWORKING-DUCKDNS-CERTMANAGER.md)
- [VAGRANT-K8S-COMMANDS.md](VAGRANT-K8S-COMMANDS.md)
- [PROJECT-MAP.md](PROJECT-MAP.md)
- [SAFE-CLEANUP-PROPOSAL.md](SAFE-CLEANUP-PROPOSAL.md)
