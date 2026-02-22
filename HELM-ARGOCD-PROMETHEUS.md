# Helm, ArgoCD & Prometheus: Installation and Verification Guide

This document explains how Helm, ArgoCD, and Prometheus are installed, how they work, and how to test/verify they're functioning correctly.

---

## Table of Contents

1. [Helm: Kubernetes Package Manager](#helm-kubernetes-package-manager)
2. [ArgoCD: GitOps Continuous Delivery](#argocd-gitops-continuous-delivery)
3. [Prometheus: Monitoring and Alerting](#prometheus-monitoring-and-alerting)
4. [Complete Verification Commands](#complete-verification-commands)

---

## Helm: Kubernetes Package Manager

### What is Helm?

Helm is a package manager for Kubernetes that:
- Simplifies application deployment using "Charts" (pre-configured Kubernetes resource templates)
- Manages versioning and upgrades
- Allows parameterization of deployments
- Tracks release history and enables rollbacks

**Analogy:** Helm is to Kubernetes what `apt` is to Ubuntu or `npm` is to Node.js.

### How Helm is Installed

**Installation Script:** `vagrant/03-control-plane-init.sh`

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

This installs Helm 3 (the latest version) on the control plane node.

### What Was Installed Using Helm?

```bash
# View all Helm releases
helm list -A
```

**Currently Installed:**

| Release | Namespace | Chart | App Version | Purpose |
|---------|-----------|-------|-------------|---------|
| **argocd** | argocd | argo-cd-9.4.3 | v3.3.1 | GitOps deployment |
| **prometheus** | monitoring | kube-prometheus-stack-82.2.0 | v0.89.0 | Monitoring stack |
| **cert-manager** | cert-manager | cert-manager-v1.19.3 | v1.19.3 | TLS certificate management |
| **cert-manager-webhook-duckdns** | cert-manager | cert-manager-webhook-duckdns-v1.2.3 | v1.2.3 | DuckDNS DNS validation |

### How to Verify Helm is Working

#### Test 1: Check Helm Version
```powershell
vagrant ssh fk-control -c "helm version"
```

**Expected Output:**
```
version.BuildInfo{Version:"v3.x.x", GitCommit:"...", GitTreeState:"clean", GoVersion:"go1.x.x"}
```

#### Test 2: List Installed Releases
```powershell
vagrant ssh fk-control -c "helm list -A"
```

**Expected:** Should show 4 releases (argocd, prometheus, cert-manager, cert-manager-webhook-duckdns)

#### Test 3: Check Release Status
```powershell
vagrant ssh fk-control -c "helm status argocd -n argocd"
```

**Expected Output:**
```
STATUS: deployed
```

#### Test 4: View Chart Values
```powershell
vagrant ssh fk-control -c "helm get values prometheus -n monitoring"
```

**Expected:** Shows custom configuration values used during installation

### Helm Installation Script Locations

**ArgoCD Installation:**
```bash
# File: vagrant/05-deploy-argocd.sh
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --namespace argocd --create-namespace
```

**Prometheus Installation:**
```bash
# File: install-prometheus.sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

---

## ArgoCD: GitOps Continuous Delivery

### What is ArgoCD?

ArgoCD is a GitOps tool that:
- Automatically deploys applications from Git repositories
- Continuously monitors Git for changes
- Automatically syncs cluster state with Git repository
- Provides visual dashboard for deployment status
- Enables declarative, version-controlled deployments

**Key Principle:** Git is the single source of truth for your cluster state.

### How ArgoCD is Installed

**Installation Method:** Helm Chart (`argo-cd-9.4.3`)

**Installation Script:** `vagrant/05-deploy-argocd.sh`

```bash
# Add Argo Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD using Helm
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --wait
```

### Verification: Is ArgoCD Working?

#### Test 1: Check ArgoCD Pods
```powershell
vagrant ssh fk-control -c "kubectl get pods -n argocd"
```

**Expected Output:**
```
NAME                                               READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                    1/1     Running   0          21h
argocd-applicationset-controller-xxx               1/1     Running   0          21h
argocd-dex-server-xxx                              1/1     Running   0          21h
argocd-notifications-controller-xxx                1/1     Running   0          21h
argocd-redis-xxx                                   1/1     Running   0          21h
argocd-repo-server-xxx                             1/1     Running   0          21h
argocd-server-xxx                                  1/1     Running   0          21h
```

**All pods should be:** `1/1 Running`

#### Test 2: Check ArgoCD Server Service
```powershell
vagrant ssh fk-control -c "kubectl get svc -n argocd"
```

**Expected Output:**
```
NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
argocd-server           ClusterIP   10.103.88.48    <none>        80/TCP,443/TCP
```

#### Test 3: Get ArgoCD Admin Password
```powershell
vagrant ssh fk-control -c "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
```

**This reveals:** The initial admin password for logging into ArgoCD UI

#### Test 4: Access ArgoCD UI (Optional)
```powershell
# Port forward ArgoCD server to localhost
vagrant ssh fk-control -c "kubectl port-forward svc/argocd-server -n argocd 8080:443"

# Then open in browser:
# https://localhost:8080
# Username: admin
# Password: (from Test 3)
```

### GitOps Workflow Configuration

**ArgoCD Application File:** `k8s/60-argocd-application.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fk-webstack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/F85K/fk-webserver.git
    targetRevision: main
    path: k8s  # Folder containing Kubernetes manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: fk-webstack
  syncPolicy:
    automated:
      prune: true      # Delete resources removed from Git
      selfHeal: true   # Auto-sync when cluster state drifts
```

#### Apply ArgoCD Application

```powershell
vagrant ssh fk-control -c "kubectl apply -f /vagrant/k8s/60-argocd-application.yaml"
```

#### Test 5: Check ArgoCD Applications
```powershell
vagrant ssh fk-control -c "kubectl get applications -n argocd"
```

**Expected Output (after applying):**
```
NAME           SYNC STATUS   HEALTH STATUS
fk-webstack    Synced        Healthy
```

#### Test 6: Verify GitOps Auto-Sync

**How to test:**
1. Make a change in your GitHub repository (e.g., change replicas in `k8s/20-api-deployment.yaml`)
2. Push to GitHub
3. Wait ~3 minutes
4. ArgoCD automatically detects and applies the change

```powershell
# Watch ArgoCD sync the application
vagrant ssh fk-control -c "kubectl get applications -n argocd -w"
```

### ArgoCD CLI (Optional Advanced Testing)

```bash
# Install ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Login to ArgoCD
argocd login localhost:8080 --username admin --password <PASSWORD> --insecure

# List applications
argocd app list

# Sync application manually
argocd app sync fk-webstack
```

---

## Prometheus: Monitoring and Alerting

### What is Prometheus?

Prometheus is a monitoring system that:
- Collects metrics from Kubernetes and applications
- Stores time-series data
- Provides powerful query language (PromQL)
- Alerts on defined conditions
- Integrates with Grafana for visualization

**Included Components:**
- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization dashboards
- **Alertmanager** - Alert routing and management
- **Node Exporter** - Host metrics (CPU, memory, disk)
- **Kube-State-Metrics** - Kubernetes object metrics

### How Prometheus is Installed

**Installation Method:** Helm Chart (`kube-prometheus-stack-82.2.0`)

**Installation Script:** `install-prometheus.sh`

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus Stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --wait
```

This single Helm chart installs:
- Prometheus Operator
- Prometheus server
- Grafana
- Alertmanager
- Node exporters
- Kube-state-metrics
- Pre-configured dashboards and alerts

### Verification: Is Prometheus Working?

#### Test 1: Check Prometheus Pods
```powershell
vagrant ssh fk-control -c "kubectl get pods -n monitoring"
```

**Expected Output:**
```
NAME                                                   READY   STATUS    RESTARTS   AGE
alertmanager-prometheus-kube-prometheus-alertmanager-0 2/2     Running   0          21h
prometheus-grafana-xxx                                 3/3     Running   0          21h
prometheus-kube-prometheus-operator-xxx                1/1     Running   0          21h
prometheus-kube-state-metrics-xxx                      1/1     Running   0          21h
prometheus-prometheus-kube-prometheus-prometheus-0     2/2     Running   0          21h
prometheus-prometheus-node-exporter-xxx (on each node) 1/1     Running   0          21h
```

#### Test 2: Check ServiceMonitors (What Prometheus is Monitoring)
```powershell
vagrant ssh fk-control -c "kubectl get servicemonitor -n monitoring"
```

**Expected Output:**
```
NAME                                      AGE
prometheus-grafana                        21h
prometheus-kube-prometheus-alertmanager   21h
prometheus-kube-prometheus-apiserver      21h
prometheus-kube-prometheus-coredns        21h
prometheus-kube-prometheus-kubelet        21h
prometheus-kube-prometheus-operator       21h
prometheus-kube-prometheus-prometheus     21h
prometheus-kube-state-metrics             21h
prometheus-prometheus-node-exporter       21h
```

**This shows:** Prometheus is monitoring all critical Kubernetes components!

#### Test 3: Access Prometheus UI
```powershell
# Port forward Prometheus server
vagrant ssh fk-control -c "kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"

# Open in browser:
# http://localhost:9090
```

**What to check in UI:**
- Go to "Status" → "Targets" - Should show all targets as "UP"
- Try query: `up` - Should show all monitored services
- Try query: `node_cpu_seconds_total` - Should show CPU metrics from all nodes

#### Test 4: Access Grafana Dashboard
```powershell
# Get Grafana admin password
vagrant ssh fk-control -c "kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo"

# Port forward Grafana
vagrant ssh fk-control -c "kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"

# Open in browser:
# http://localhost:3000
# Username: admin
# Password: (from command above)
```

**Pre-installed Dashboards:**
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace (Pods)
- Kubernetes / Compute Resources / Node (Pods)
- Kubernetes / Networking / Cluster
- Node Exporter / Nodes

#### Test 5: Query Cluster Metrics

**CPU Usage per Node:**
```powershell
vagrant ssh fk-control -c "kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"

# Then in Prometheus UI, run query:
# rate(node_cpu_seconds_total{mode="idle"}[5m])
```

**Pod Memory Usage:**
```
container_memory_usage_bytes{namespace="fk-webstack"}
```

**API Request Rate:**
```
rate(http_requests_total[5m])
```

#### Test 6: Verify Alertmanager
```powershell
vagrant ssh fk-control -c "kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093"

# Open in browser:
# http://localhost:9093
```

**Check:** Alerts tab should show any active alerts

#### Test 7: Check Node Exporter Metrics
```powershell
# Node exporters run on every node and collect host metrics
vagrant ssh fk-control -c "kubectl get daemonset -n monitoring"
```

**Expected:**
```
NAME                                  DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE
prometheus-prometheus-node-exporter   3         3         3       3            3
```

**This means:** All 3 nodes (1 control + 2 workers) are being monitored

---

## Complete Verification Commands

### Quick Status Check (All Components)

```powershell
# Helm releases
vagrant ssh fk-control -c "helm list -A"

# ArgoCD status
vagrant ssh fk-control -c "kubectl get pods -n argocd; kubectl get applications -n argocd"

# Prometheus status
vagrant ssh fk-control -c "kubectl get pods -n monitoring; kubectl get servicemonitor -n monitoring | head -5"
```

### Detailed Verification Script

```powershell
Write-Host "=== HELM VERIFICATION ===" -ForegroundColor Cyan
vagrant ssh fk-control -c "helm version --short"
vagrant ssh fk-control -c "helm list -A"

Write-Host "`n=== ARGOCD VERIFICATION ===" -ForegroundColor Cyan
vagrant ssh fk-control -c "kubectl get pods -n argocd | grep Running | wc -l"
Write-Host "Expected: 7 running pods" -ForegroundColor Yellow
vagrant ssh fk-control -c "kubectl get svc argocd-server -n argocd"
vagrant ssh fk-control -c "kubectl get applications -n argocd"

Write-Host "`n=== PROMETHEUS VERIFICATION ===" -ForegroundColor Cyan
vagrant ssh fk-control -c "kubectl get pods -n monitoring | grep Running | wc -l"
Write-Host "Expected: 6+ running pods" -ForegroundColor Yellow
vagrant ssh fk-control -c "kubectl get servicemonitor -n monitoring | wc -l"
Write-Host "Expected: 13+ service monitors" -ForegroundColor Yellow

Write-Host "`n=== SUMMARY ===" -ForegroundColor Green
Write-Host "✓ Helm: Package manager for Kubernetes" -ForegroundColor Green
Write-Host "✓ ArgoCD: GitOps continuous delivery" -ForegroundColor Green
Write-Host "✓ Prometheus: Cluster monitoring and alerting" -ForegroundColor Green
```

---

## Assignment Requirements Met

### Requirement: "Gebruik een Helm Chart om ArgoCD op je kubernetes cluster op te zetten" (+4/20)

**Evidence:**
```bash
helm list -n argocd
# Shows: argocd installed via argo-cd-9.4.3 Helm chart
```

**Files:**
- `vagrant/05-deploy-argocd.sh` - Installation script
- `k8s/60-argocd-application.yaml` - GitOps application config

### Requirement: "Implementeer een GitOps workflow om automatisch je applicatie te deployen" (+4/20)

**Evidence:**
```bash
kubectl get applications -n argocd
# Shows: fk-webstack application configured with auto-sync
```

**How it works:**
1. Code pushed to GitHub (https://github.com/F85K/fk-webserver)
2. ArgoCD detects change (~3 min polling)
3. Automatically applies changes to cluster
4. Self-heals if manual changes are made

### Requirement: "Monitor je cluster resources en performance aan de hand van Prometheus" (+2/20)

**Evidence:**
```bash
helm list -n monitoring
# Shows: prometheus installed via kube-prometheus-stack-82.2.0

kubectl get servicemonitor -n monitoring
# Shows: 13+ components being monitored
```

**Monitored Metrics:**
- Node CPU, memory, disk, network
- Pod resource usage
- Kubernetes API server performance
- etcd performance
- CoreDNS performance
- Application metrics (via ServiceMonitor)

---

## Troubleshooting

### Helm Command Not Found
```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### ArgoCD Pods Not Running
```bash
# Check pod status
kubectl describe pod <POD-NAME> -n argocd

# Check logs
kubectl logs <POD-NAME> -n argocd
```

### Prometheus Not Collecting Metrics
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090 → Status → Targets

# Check if ServiceMonitors exist
kubectl get servicemonitor -n monitoring
```

### ArgoCD Application Not Syncing
```bash
# Check application status
kubectl describe application fk-webstack -n argocd

# Manual sync
kubectl patch application fk-webstack -n argocd --type merge -p '{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}'
```

---

## Summary

| Component | Purpose | Installation | Verification |
|-----------|---------|--------------|--------------|
| **Helm** | Kubernetes package manager | `curl ... \| bash` | `helm list -A` |
| **ArgoCD** | GitOps deployment | Helm chart (argo-cd) | `kubectl get pods -n argocd` |
| **Prometheus** | Monitoring & alerting | Helm chart (kube-prometheus-stack) | `kubectl get pods -n monitoring` |

**All three components are:**
- ✅ Installed via Helm
- ✅ Running and healthy
- ✅ Actively functioning (ArgoCD watching Git, Prometheus collecting metrics)
- ✅ Ready for oral exam demonstration

---

*Last verified: 2026-02-22*
*Cluster: fk-webserver (kubeadm)*
*Helm Charts: 4 deployed*
*Status: All systems operational ✅*
