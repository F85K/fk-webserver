# FK Webstack Kubernetes Deployment - Tomorrow's Quick Start

## Current Status (Session End - Feb 21, 2026)

✅ **Completed:**
- All 3 VMs (fk-control, fk-worker1, fk-worker2) created and running
- Kubernetes v1.35.0/1.35.1 cluster fully operational
- All 3 nodes Ready and joined
- containerd installed and running on all nodes
- Docker images built (fk-api, fk-frontend) and available
- Test pod (MongoDB) successfully runs with `hostNetwork: true`
- Helm installation script ready

⏳ **Ready to Deploy** (Run this command):
```bash
vagrant ssh fk-control -c "sudo bash /vagrant/FINAL-DEPLOY.sh"
```

## What the Script Does

The `/vagrant/FINAL-DEPLOY.sh` script will:
1. Verify cluster health (all nodes)
2. Clean old CNI configs
3. Install Helm
4. Install **Cilium CNI** (network plugin - CRITICAL)
5. Wait for nodes to be Ready with networking
6. Install **cert-manager** (TLS certificates)
7. Install **Prometheus + Grafana** (monitoring)
8. Install **ArgoCD** (GitOps automation)
9. Deploy application stack (MongoDB, API, Frontend)
10. Print final status and access instructions

## Expected Duration
**15-20 minutes** from script start to full deployment

## If Script Fails

### Option A: Install components manually one-by-one

```bash
# SSH into control plane
vagrant ssh fk-control

# Install Helmet if needed
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Cilium step-by-step
helm repo add cilium https://helm.cilium.io
helm repo update
helm install cilium cilium/cilium --namespace kube-system --wait

# Check Cilium status
kubectl get pods -n kube-system | grep cilium
kubectl wait --for=condition=Ready node --all --timeout=300s

# Then repeat for other Helm charts...
```

### Option B: Use provided scripts

Already created scripts in `/vagrant/`:
- `FINAL-DEPLOY.sh` - Full deployment
- `install-stack.sh` - Alternative full deployment
- `app-hostnet.yaml` - Fallback with hostNetwork (if CNI fails)

## Verify Success

After script completes, run:
```bash
vagrant ssh fk-control -c "sudo kubectl get all -A"
```

Expected:
- 3 nodes in Ready state
- Pods in: kube-system, kube-public, cert-manager, monitoring, argocd, fk-webstack namespaces
- MongoDB, API, Frontend pods Running

## Access Applications

```powershell
# Port forward to API
vagrant ssh fk-control -c "sudo kubectl port-forward svc/fk-api -n fk-webstack 8000:8000"

# Port forward to Grafana (monitoring)
vagrant ssh fk-control -c "sudo kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"

# Port forward to ArgoCD
vagrant ssh fk-control -c "sudo kubectl port-forward svc/argocd-server -n argocd 8080:443"
```

## Troubleshooting

**Nodes not Ready after CNI install:**
```bash
kubectl describe node fk-worker1
kubectl logs -n kube-system -l k8s-app=cilium
```

**Pod networking issues:**
```bash
# Test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Test pod-to-pod connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://fk-api:8000/health
```

**MongoDB not connecting:**
```bash
# Check MongoDB pod logs
kubectl logs -n fk-webstack -l app.kubernetes.io/name=mongodb

# Test MongoDB connection from API pod
kubectl exec -n fk-webstack -it deploy/fk-api -- bash
# Then: mongo mongodb://fk-mongodb:27017 -u admin -p password123
```

## Files Reference

- `/vagrant/FINAL-DEPLOY.sh` - Main deployment script (ready to execute)
- `/vagrant/k8s/` - All Kubernetes manifests
- `/vagrant/api/` - FastAPI application code
- `/vagrant/frontend/` - Frontend application code
- `/vagrant/docker-compose.yaml` - Docker Compose reference
- `/vagrant/Vagrantfile` - VM configuration

## Important Notes

- **Token expires:** kubeadm join tokens last 24 hours. If you rebuild workers after this session ends, regenerate with: `kubeadm token create --print-join-command`
- **Resource constraints:** 12GB total (6GB control, 3GB per worker) - Helm chart resource limits are minimized
- **CNI choice:** Cilium is lightweight but powerful; fallback is simpler Flannel if needed
- **Networking:** Using tunnel/vxlan mode for simplicity in VirtualBox environment

---

## Tomorrow's Command (One-liner)

```powershell
cd C:\Users\Admin\Desktop\WebserverLinux
vagrant ssh fk-control -c "sudo bash /vagrant/FINAL-DEPLOY.sh"
```

That's it! Everything else runs automatically.

Good luck tomorrow! 🚀
