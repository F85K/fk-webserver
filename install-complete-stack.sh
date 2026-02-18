#!/bin/bash
set -e

echo "======================================"
echo "Complete Stack Installation"
echo "======================================"
echo ""
echo "Memory available: 12GB total"
echo "Control plane: 6GB | Workers: 3GB each"
echo ""

# Step 1: Clean everything first
echo "Step 1: Cleaning up..."
kubectl delete namespace fk-webstack 2>/dev/null || echo "fk-webstack not found"
kubectl delete namespace cert-manager 2>/dev/null || echo "cert-manager not found"
kubectl delete namespace monitoring 2>/dev/null || echo "monitoring not found"
kubectl delete namespace argocd 2>/dev/null || echo "argocd not found"
sleep 5

# Step 2: Redeploy core application stack
echo ""
echo "Step 2: Deploying core application stack..."
kubectl create namespace fk-webstack
kubectl apply -f /vagrant/k8s/10-mongodb-deployment.yaml
sleep 10
kubectl apply -f /vagrant/k8s/13-mongodb-init-job.yaml
sleep 5
kubectl apply -f /vagrant/k8s/20-api-deployment.yaml
sleep 3
kubectl apply -f /vagrant/k8s/21-api-service.yaml
sleep 2
kubectl apply -f /vagrant/k8s/30-frontend-deployment.yaml
sleep 2
kubectl apply -f /vagrant/k8s/31-frontend-service.yaml

echo ""
echo "Waiting for core apps to start..."
sleep 30

# Step 3: Install cert-manager
echo ""
echo "Step 3: Installing cert-manager (TLS)..."
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update
helm install cert-manager jetstack/cert-manager \
  -n cert-manager \
  --create-namespace \
  --set installCRDs=true 2>&1 | tail -3

echo "Waiting for cert-manager..."
sleep 15

# Step 4: Install Prometheus for monitoring
echo ""
echo "Step 4: Installing Prometheus (Monitoring)..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update
helm install fk-monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.limits.memory=1Gi \
  --set grafana.resources.requests.memory=128Mi \
  --set grafana.resources.limits.memory=512Mi \
  --set alertmanager.enabled=false \
  --set nodeExporter.resources.limits.memory=128Mi 2>&1 | tail -3

echo "Waiting for Prometheus stack..."
sleep 20

# Step 5: Install ArgoCD
echo ""
echo "Step 5: Installing ArgoCD (GitOps)..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update
helm install argocd argo/argo-cd \
  -n argocd \
  --create-namespace \
  --skip-crds 2>&1 | tail -3

echo "Waiting for ArgoCD..."
sleep 20

# Step 6: Apply ArgoCD application
echo ""
echo "Step 6: Applying ArgoCD application..."
kubectl apply -f /vagrant/k8s/60-argocd-application.yaml 2>/dev/null || echo "ArgoCD CRDs not ready yet"

echo ""
echo "======================================"
echo "FINAL STATUS"
echo "======================================"
echo ""
echo "Cluster nodes:"
kubectl get nodes
echo ""
echo "Namespaces:"
kubectl get ns
echo ""
echo "Core application (fk-webstack):"
kubectl get pods -n fk-webstack -o wide

echo ""
echo "cert-manager:"
kubectl get pods -n cert-manager -o wide 2>/dev/null || echo "Starting..."

echo ""
echo "Prometheus & Grafana:"
kubectl get pods -n monitoring -o wide 2>/dev/null || echo "Starting..."

echo ""
echo "ArgoCD:"
kubectl get pods -n argocd -o wide 2>/dev/null || echo "Starting..."

echo ""
echo "======================================"
echo "✅ Installation complete!"
echo "======================================"
echo ""
echo "Access Grafana (monitoring):"
echo "  kubectl port-forward -n monitoring svc/fk-monitoring-grafana 3000:80"
echo "  User: admin"
echo "  Password: prom-operator"
echo ""
echo "Access Prometheus:"
echo "  kubectl port-forward -n monitoring svc/fk-monitoring-prometheus 9090:9090"
echo ""
echo "Access ArgoCD:"
echo "  kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo ""
echo "Test API:"
echo "  kubectl port-forward -n fk-webstack svc/fk-api 8000:8000"
echo "  Then: Invoke-RestMethod http://localhost:8000/api/name"
