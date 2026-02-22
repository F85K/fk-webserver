#!/bin/bash
set -e

echo "======================================"
echo "Incremental Stack Deployment"
echo "======================================"
echo "NOTE: Does NOT delete existing resources"
echo ""

# Step 1: Deploy core application
echo "Step 1: Deploying core application stack..."
kubectl create namespace fk-webstack 2>/dev/null || echo "Namespace exists"
kubectl apply -f /vagrant/k8s/11-mongodb-service.yaml 2>/dev/null || echo "MongoDB service exists"
kubectl apply -f /vagrant/k8s/10-mongodb-deployment.yaml 2>/dev/null || kubectl rollout restart deployment fk-mongodb -n fk-webstack
sleep 15
kubectl apply -f /vagrant/k8s/13-mongodb-init-job.yaml 2>/dev/null || kubectl delete job fk-mongo-init-job -n fk-webstack; kubectl apply -f /vagrant/k8s/13-mongodb-init-job.yaml
sleep 10
kubectl apply -f /vagrant/k8s/20-api-deployment.yaml 2>/dev/null || kubectl rollout restart deployment fk-api -n fk-webstack
kubectl apply -f /vagrant/k8s/21-api-service.yaml 2>/dev/null || echo "API service exists"
sleep 10
kubectl apply -f /vagrant/k8s/30-frontend-deployment.yaml 2>/dev/null || kubectl rollout restart deployment fk-frontend -n fk-webstack
kubectl apply -f /vagrant/k8s/31-frontend-service.yaml 2>/dev/null || echo "Frontend service exists"

echo ""
echo "Waiting for core apps (30s)..."
sleep 30

echo ""
echo "Step 2: Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update >/dev/null 2>&1
helm list -n cert-manager 2>/dev/null | grep -q cert-manager && echo "cert-manager already installed" || \
helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set installCRDs=true --wait --timeout 3m

echo ""
echo "Step 3: Installing Prometheus (with resource limits)..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update >/dev/null 2>&1
helm list -n monitoring 2>/dev/null | grep -q fk-monitoring && echo "Prometheus already installed" || \
helm install fk-monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.limits.memory=1Gi \
  --set grafana.enabled=true \
  --set grafana.resources.requests.memory=128Mi \
  --set grafana.resources.limits.memory=512Mi \
  --set alertmanager.enabled=false \
  --set nodeExporter.resources.limits.memory=128Mi \
  --wait --timeout 5m

echo ""
echo "Step 4: Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update >/dev/null 2>&1
helm list -n argocd 2>/dev/null | grep -q argocd && echo "ArgoCD already installed" || \
kubectl create namespace argocd 2>/dev/null; \
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

sleep 20

echo ""
echo "======================================"
echo "DEPLOYMENT STATUS"  
echo "======================================"
echo ""
echo "Nodes:"
kubectl get nodes -o wide

echo ""
echo "Core Application:"
kubectl get pods -n fk-webstack -o wide

echo ""
echo "cert-manager:"
kubectl get pods -n cert-manager --no-headers 2>/dev/null || echo "Not yet ready"

echo ""
echo "Monitoring:"
kubectl get pods -n monitoring --no-headers 2>/dev/null | head -5 || echo "Not yet ready"

echo ""
echo "ArgoCD:"
kubectl get pods -n argocd --no-headers 2>/dev/null | head -5 || echo "Not yet ready"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Access services:"
echo "  kubectl port-forward svc/fk-api -n fk-webstack 8000:8000"
echo "  kubectl port-forward svc/fk-monitoring-grafana -n monitoring 3000:80"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
