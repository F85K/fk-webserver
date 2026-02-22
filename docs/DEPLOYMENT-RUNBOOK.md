# Deployment Runbook (Manual Provisioning)

This runbook installs the full project stack on top of the bare VMs.

## Assumptions

- Bare VMs are already created with `vagrant up`.
- Shared folder is mounted at `/vagrant` on all VMs.
- Control plane IP: `192.168.56.10`

---

## Step 1: Provision Control Plane (fk-control)

From Windows PowerShell:

```powershell
vagrant ssh fk-control
```

Inside the VM:

```bash
# Base setup
bash /vagrant/vagrant/01-base-setup.sh

# Install Kubernetes tooling
bash /vagrant/vagrant/02-kubeadm-install.sh

# Initialize control plane
bash /vagrant/vagrant/03-control-plane-init.sh

# Verify control plane
kubectl get nodes
kubectl get pods -n kube-flannel
```

Expected:
- `fk-control` is Ready.
- Flannel pods are Running.

---

## Step 2: Provision Worker Nodes

From Windows PowerShell, run these sequentially:

```powershell
vagrant ssh fk-worker1 -c "bash /vagrant/vagrant/01-base-setup.sh && bash /vagrant/vagrant/02-kubeadm-install.sh && bash /vagrant/vagrant/04-worker-join.sh"

vagrant ssh fk-worker2 -c "bash /vagrant/vagrant/01-base-setup.sh && bash /vagrant/vagrant/02-kubeadm-install.sh && bash /vagrant/vagrant/04-worker-join.sh"
```

Back in fk-control:

```bash
kubectl get nodes
```

Expected:
- `fk-worker1` and `fk-worker2` become Ready within 1-2 minutes.

---

## Step 3: Build and Load Images (fk-control)

Inside fk-control:

```bash
cd /vagrant

# Build images
sudo docker build -t fk-api:latest ./api
sudo docker build -t fk-frontend:latest ./frontend

# Export to tar
sudo docker save fk-api:latest -o /tmp/fk-api.tar
sudo docker save fk-frontend:latest -o /tmp/fk-frontend.tar

# Import into containerd
sudo ctr -n k8s.io images import /tmp/fk-api.tar
sudo ctr -n k8s.io images import /tmp/fk-frontend.tar

# Verify
sudo crictl images | grep -E "fk-api|fk-frontend"
```

---

## Step 4: Deploy the Full Stack (fk-control)

Inside fk-control:

```bash
bash /vagrant/vagrant/deploy-full-stack.sh
```

This installs:
- MongoDB + init job
- API + HPA
- Frontend
- cert-manager
- Prometheus/Grafana
- ArgoCD

---

## Step 5: Verify

Inside fk-control:

```bash
# Pods
kubectl get pods -n fk-webstack

# API
kubectl port-forward svc/fk-api -n fk-webstack 8000:8000 &
sleep 2
curl http://localhost:8000/health
curl http://localhost:8000/api/name
jobs
kill %1

# Frontend
kubectl port-forward svc/fk-frontend -n fk-webstack 8080:8080 &
sleep 2
curl http://localhost:8080
jobs
kill %1

# Full verification
bash /vagrant/vagrant/verify-success-criteria.sh
```

---

## Step 6: Optional UI Access (from Windows browser)

```bash
# Grafana
kubectl port-forward svc/fk-monitoring-grafana -n monitoring 3000:80
# http://localhost:3000 (admin / admin)

# ArgoCD
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443
# https://localhost:8080
```
