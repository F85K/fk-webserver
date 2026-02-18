# FK Webstack Troubleshooting Guide

## Common Issues and Solutions

### 1. Worker Nodes Not Ready (Flannel CrashLoopBackOff)

**Symptoms:**
- `kubectl get nodes` shows workers in `NotReady` state
- Flannel pods in `CrashLoopBackOff`
- Error: "failed to load flannel 'subnet.env' file"

**Root Cause:**
- Workers joined before Flannel was fully initialized on control plane
- Flannel CNI plugin not loaded properly by kubelet

**Solution:**
```bash
# Option A: Reload the worker VM (cleanest)
vagrant reload fk-worker1
vagrant reload fk-worker2

# Option B: Restart kubelet on worker
vagrant ssh fk-worker1 -c "sudo systemctl restart kubelet"
vagrant ssh fk-worker2 -c "sudo systemctl restart kubelet"

# Option C: Full Flannel reset (on control plane)
vagrant ssh fk-control -c "
  kubectl delete ds/kube-flannel-ds -n kube-flannel
  kubectl apply -f https://github.com/flannel-io/flannel/releases/download/v0.25.1/kube-flannel.yml
"
```

**Prevention:**
The updated `04-worker-join.sh` now waits for Flannel to be ready before joining.

---

### 2. Pods Stuck in Terminating State

**Symptoms:**
- Pods show `Terminating` status for minutes/hours
- `kubectl delete pod` hangs indefinitely

**Root Cause:**
- Finalizers blocking deletion
- Node NotReady causing pod eviction failures

**Solution:**
```bash
# Use the cleanup script
vagrant ssh fk-control -c "bash /vagrant/cleanup-stuck-resources.sh"

# Or manually force delete
vagrant ssh fk-control -c "
  kubectl delete pod POD_NAME -n NAMESPACE --grace-period=0 --force
"
```

---

### 3. Prometheus Crashing Cluster (Too Many Pods)

**Symptoms:**
- API server becomes unresponsive after installing Prometheus
- 20+ monitoring pods created
- Node memory exhaustion

**Root Cause:**
- kube-prometheus-stack deploys many components without resource limits
- 6GB control plane can't handle default configuration

**Solution:**
The updated `deploy-full-stack.sh` includes strict resource limits:
- Prometheus: 256Mi-1Gi memory
- Grafana: 128Mi-512Mi memory
- Alertmanager: Disabled
- Node exporter: 64Mi-128Mi memory

**Manual Fix:**
```bash
# Uninstall problematic Prometheus
vagrant ssh fk-control -c "helm uninstall fk-monitoring -n monitoring"

# Reinstall with limits
vagrant ssh fk-control -c "bash /vagrant/deploy-full-stack.sh"
```

---

### 4. ArgoCD Helm Installation Timeout

**Symptoms:**
- `helm install argo-cd` hangs on "pre-install hook"
- Timeout after 5 minutes

**Root Cause:**
- ArgoCD Helm chart has complex pre-install hooks
- Redis secret initialization slow on resource-constrained cluster

**Solution:**
The updated `deploy-full-stack.sh` uses Helm with proper timeouts and resource limits.

**Alternative:**
```bash
# Use kubectl instead of Helm
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

---

### 5. CoreDNS in ContainerCreating State

**Symptoms:**
- CoreDNS pods stuck in `ContainerCreating`
- Error: "network not ready: NetworkReady=false"

**Root Cause:**
- Flannel CNI not ready when CoreDNS tries to start

**Solution:**
```bash
# Check Flannel status first
vagrant ssh fk-control -c "kubectl get pods -n kube-flannel"

# If Flannel is running, delete CoreDNS pods to restart them
vagrant ssh fk-control -c "
  kubectl delete pods -n kube-system -l k8s-app=kube-dns
"
```

---

### 6. cert-manager Components Crashing

**Symptoms:**
- cert-manager-cainjector in `CrashLoopBackOff`
- cert-manager-webhook in `CrashLoopBackOff`

**Root Cause:**
- Insufficient resources
- Webhook trying to start before CRDs are ready

**Solution:**
The updated `deploy-full-stack.sh` includes resource limits for cert-manager components.

**Manual Fix:**
```bash
# Reinstall with resource limits
vagrant ssh fk-control -c "
  helm uninstall cert-manager -n cert-manager
  kubectl delete namespace cert-manager
  bash /vagrant/deploy-full-stack.sh
"
```

---

### 7. MongoDB Connection Errors from API

**Symptoms:**
- API pods crash with "Cannot connect to MongoDB"
- MongoDB pod is running but not accepting connections

**Root Cause:**
- MongoDB not fully initialized when API starts
- Network connectivity issues

**Solution:**
```bash
# Check MongoDB logs
vagrant ssh fk-control -c "kubectl logs -n fk-webstack -l app=fk-mongodb"

# Check MongoDB service
vagrant ssh fk-control -c "kubectl get svc -n fk-webstack fk-mongodb"

# Restart API pods
vagrant ssh fk-control -c "kubectl rollout restart deployment/fk-api -n fk-webstack"
```

---

## Complete Rebuild Procedure

If issues persist, do a clean rebuild:

```powershell
# 1. Destroy all VMs
vagrant destroy -f

# 2. Clean up any cached state
Remove-Item -Path "kubeadm-config/*" -Force -ErrorAction SilentlyContinue

# 3. Bring up VMs fresh
vagrant up

# 4. Wait for all nodes to be Ready (5-10 minutes)
vagrant ssh fk-control -c "kubectl get nodes"

# 5. Deploy full stack
vagrant ssh fk-control -c "bash /vagrant/deploy-full-stack.sh"

# 6. Verify success criteria
vagrant ssh fk-control -c "bash /vagrant/verify-success-criteria.sh"

# 7. Test API
vagrant ssh fk-control -c "kubectl port-forward svc/fk-api -n fk-webstack 8000:8000" &
Start-Sleep 5
Invoke-RestMethod http://localhost:8000/api/name
```

---

## Verification Commands

### Check Overall Health
```bash
kubectl get nodes                          # All should be Ready
kubectl get pods -A                        # Most should be Running
kubectl top nodes                          # Check resource usage
kubectl get events -A --sort-by='.lastTimestamp'  # Recent events
```

### Check Specific Components
```bash
# Application
kubectl get pods -n fk-webstack -o wide
kubectl logs -n fk-webstack -l app=fk-api

# Monitoring
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# GitOps
kubectl get pods -n argocd
kubectl get applications -n argocd

# TLS
kubectl get pods -n cert-manager
kubectl get clusterissuer
```

### Resource Usage
```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu
```

---

## Performance Tuning

### If Control Plane Struggles (6GB RAM)

1. **Reduce Prometheus retention:**
   Edit `deploy-full-stack.sh`, change:
   ```bash
   --set prometheus.prometheusSpec.retention=3h \
   ```

2. **Disable node-exporter on workers:**
   ```bash
   --set nodeExporter.enabled=false \
   ```

3. **Use smaller Grafana image:**
   ```bash
   --set grafana.image.tag=9.5.0-alpine \
   ```

### If Workers Are Struggling (3GB RAM)

1. **Reduce API HPA max replicas:**
   Edit `k8s/22-api-hpa.yaml`:
   ```yaml
   maxReplicas: 2  # Instead of 4
   ```

2. **Set pod resource limits:**
   Edit `k8s/20-api-deployment.yaml`:
   ```yaml
   resources:
     limits:
       memory: "256Mi"
       cpu: "500m"
   ```

---

## Success Criteria Checklist

- [ ] **Docker Stack:** MongoDB, API, Frontend pods Running
- [ ] **Kubernetes:** 3 nodes (1 control + 2 workers) all Ready
- [ ] **Live Data:** MongoDB init job completed, API returns data
- [ ] **TLS:** cert-manager installed, issuers configured
- [ ] **Monitoring:** Prometheus and Grafana accessible
- [ ] **GitOps:** ArgoCD installed, fk-webstack-app configured
- [ ] **Secrets:** No hardcoded credentials in Git
- [ ] **Logging:** (Optional) Not yet implemented

---

## Quick Commands Reference

```bash
# Rebuild everything
vagrant destroy -f && vagrant up

# Deploy stack
vagrant ssh fk-control -c "bash /vagrant/deploy-full-stack.sh"

# Verify criteria
vagrant ssh fk-control -c "bash /vagrant/verify-success-criteria.sh"

# Cleanup stuck resources
vagrant ssh fk-control -c "bash /vagrant/cleanup-stuck-resources.sh"

# Access services
vagrant ssh fk-control -c "kubectl port-forward svc/fk-api -n fk-webstack 8000:8000"
vagrant ssh fk-control -c "kubectl port-forward svc/fk-monitoring-grafana -n monitoring 3000:80"
vagrant ssh fk-control -c "kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443"

# Get ArgoCD password
vagrant ssh fk-control -c "kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d"
```
