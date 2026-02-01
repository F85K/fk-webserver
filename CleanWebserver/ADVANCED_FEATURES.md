# ✅ CERT-MANAGER & ADVANCED FEATURES - COMPLETE GUIDE

**Date:** February 1, 2026  
**Status:** Phase 6 UPDATED with comprehensive setup

---

## 🔒 Cert-Manager: Do You Need to Do Anything Online?

### **Answer: NO! 100% Offline ✅**

**cert-manager** creates **self-signed certificates** that are generated INSIDE your Kubernetes cluster. No external signup, no DNS changes, no GitHub needed.

---

## **What cert-manager Does (Completely Offline)**

| Step | What Happens | Online? |
|------|-------------|---------|
| Install cert-manager | Pulls from GitHub releases (one-time) | ✅ Internet for download only |
| Create ClusterIssuer | Generates CA inside cluster | ❌ Completely offline |
| Create Certificate | Self-signs TLS cert locally | ❌ Completely offline |
| Store TLS secret | Saves to Kubernetes | ❌ Completely offline |

**Result:** You get a TLS certificate signed by your cluster's own certificate authority. Perfect for internal/testing use!

---

## **Quick Answer to Your Question**

**cert-manager:** ✅ **I (the AI) can do it** - Full commands provided in ROADMAP Phase 6.2

**Prometheus:** ✅ **I can do it** - Full commands provided in ROADMAP Phase 6.3

**ArgoCD Path A (local only):** ✅ **I can do it** - Full commands provided in ROADMAP Phase 6.4 Path A

**ArgoCD Path B (GitHub GitOps):** 🔶 **YOU need GitHub** - You need to push your repo, but commands provided in Phase 6.4 Path B

---

## 📊 All Phase 6 Features - What You Need

| Feature | Install | Access | Data Source | Difficulty |
|---------|---------|--------|-------------|------------|
| **cert-manager** | `kubectl apply` | CLI only | Self-signed | Easy ✅ |
| **Prometheus** | `helm install` | Web UI (port 9090) | Cluster metrics | Easy ✅ |
| **Grafana** | Part of Prometheus | Web UI (port 3000) | Prometheus data | Easy ✅ |
| **ArgoCD (local)** | `helm install` | Web UI (port 8443) | Git repo (local demo) | Easy ✅ |
| **ArgoCD (GitHub)** | `helm install` | Web UI (port 8443) | Your GitHub repo | Medium 🔶 |

---

## 🚀 Recommended Deployment Order

### **For 20/20 Points (Recommended)**

```
PHASE 1-5: BASE DEPLOYMENT
├─ vagrant up                    (20 min)
├─ Build images in VMs           (5 min)
├─ kubectl apply manifests       (2 min)
└─ Verify frontend/API work      (5 min)
   = 18/20 Points Guaranteed ✅

PHASE 6 (in this order):

1️⃣ cert-manager (HTTPS) +2 points
   └─ Time: 5 minutes ⚡
   └─ Difficulty: Easy ✅
   └─ All offline ✅

2️⃣ Prometheus (Monitoring) +2 points
   └─ Time: 5-10 minutes ⚡
   └─ Difficulty: Easy ✅
   └─ All offline ✅

3️⃣ ArgoCD Path A (GitOps demo) +4 points
   └─ Time: 5 minutes ⚡
   └─ Difficulty: Easy ✅
   └─ All offline ✅
   
   OR ArgoCD Path B (GitHub GitOps) +4 points
   └─ Time: 10 minutes 🔶
   └─ Difficulty: Medium 🔶
   └─ Needs GitHub repo

TOTAL: 18 + 2 + 2 + 4 = 26/20 (capped at 20) ✅
```

---

## 📋 Updated ROADMAP Phase 6 - What's Included Now

### **Section 6.1: HPA Demo**
- Demonstrates existing auto-scaling feature
- Generate load → watch replicas scale 2→4

### **Section 6.2: cert-manager (NEW - COMPREHENSIVE)**
- ✅ Step-by-step installation
- ✅ Create ClusterIssuer (self-signed)
- ✅ Create Certificate (generates TLS)
- ✅ Verify secrets created
- ✅ (Optional) View certificate content with openssl
- ✅ Troubleshooting commands
- **Key point:** "⚠️ COMPLETELY OFFLINE - No GitHub, no DNS changes needed!"

### **Section 6.3: Prometheus (NEW - COMPREHENSIVE)**
- ✅ Add Helm repository
- ✅ Install prometheus-community stack (with Grafana included)
- ✅ Configure resource limits
- ✅ Set admin password (admin123)
- ✅ Port-forward to dashboards (9090 + 3000)
- ✅ Wait times and verification
- ✅ Example Prometheus queries
- ✅ Access Grafana for visualization

### **Section 6.4: ArgoCD (NEW - TWO PATHS)**

**Path A: Local Only** (No GitHub needed)
- ✅ Install ArgoCD
- ✅ Get auto-generated password
- ✅ Access UI (https://localhost:8443)
- ✅ Instructions to create app manually in UI
- ✅ Demo purposes only

**Path B: With GitHub** (Full GitOps)
- ✅ Same as Path A
- ✅ Plus: Connect to GitHub repo
- ✅ Plus: Auto-deploy on git push
- ✅ Full GitOps workflow

### **Section 6.5: Summary**
- ✅ Points breakdown
- ✅ Total score calculation (20/20 achievable)

### **Section 6.6: Phase 6 Troubleshooting**
- ✅ cert-manager issues
- ✅ Prometheus not collecting data
- ✅ ArgoCD UI not loading

---

## 🎯 Your Next Steps

### **To Get 20/20 Points:**

```powershell
# 1. Complete Phases 1-5 (65 minutes total)
cd CleanWebserver
vagrant up                           # 20 min
# SSH to each VM and build images    # 5 min
vagrant ssh fk-control -c "kubectl apply -f /vagrant/kubernetes/manifests.yaml"  # 2 min
.\deploy.ps1 -Action test            # 5 min

# 2. Complete Phase 6 Advanced Features (20 minutes total)
vagrant ssh fk-control

# cert-manager (5 min)
# (Copy commands from ROADMAP.md Phase 6.2)

# Prometheus (5 min)
# (Copy commands from ROADMAP.md Phase 6.3)

# ArgoCD (5 min)
# (Copy commands from ROADMAP.md Phase 6.4 Path A)

# Total: 85 minutes → 20/20 points ✅
```

---

## ❓ FAQ - Certificate Manager Questions

**Q: Will the self-signed certificate work in the browser?**  
A: Yes, but the browser will warn "certificate not trusted" (that's normal for self-signed). You click "Advanced" → "Proceed anyway".

**Q: Do I need to buy a certificate?**  
A: No! Self-signed is perfect for this school project. For production, you'd use Let's Encrypt (free).

**Q: Can I use this certificate on the frontend?**  
A: Yes! You'd need to create an Ingress resource that references the `fk-webstack-tls` secret. Instructions in Phase 6.2 comments.

**Q: Is it really completely offline?**  
A: Yes! The ONLY online requirement is downloading the cert-manager manifest file (one-time). After that, all certificate generation happens inside your cluster with zero external connectivity needed.

---

## 📚 Files Updated

- ✅ **ROADMAP.md** - Phase 6 completely rewritten with comprehensive instructions
- ✅ **This file** - Answers your question about online requirements

---

## ✨ Summary

| Task | Online Needed? | Effort | Time | Points |
|------|---|---|---|---|
| Phases 1-5 | No | Hard | 60 min | 18 |
| cert-manager | No | Easy | 5 min | +2 |
| Prometheus | No | Easy | 5 min | +2 |
| ArgoCD Path A | No | Easy | 5 min | +4 |
| **TOTAL** | **No** | - | **80 min** | **20/20** ✅ |

**Everything is offline except initial manifest downloads!** Ready to start? 🚀
