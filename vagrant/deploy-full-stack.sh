#!/bin/bash
# Comprehensive deployment script for FK Webstack with monitoring and GitOps

set -e

echo "======================================"
echo "FK Webstack Full Stack Deployment"
echo "======================================"
echo ""

KUBECONFIG=/root/.kube/config
export KUBECONFIG

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper function for status
status() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# Verify cluster is ready
echo "Step 1: Verifying cluster status..."
if ! kubectl get nodes &>/dev/null; then
    error "Cannot connect to Kubernetes API server"
    exit 1
fi

READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")

echo "  Cluster nodes: $READY_NODES/$TOTAL_NODES Ready"

if [ "$READY_NODES" -lt 2 ]; then
    warn "Not all nodes are Ready. Deployment may have issues."
    echo "  Current node status:"
    kubectl get nodes
    read -p "  Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

status "Cluster is accessible"
echo ""

# Deploy core application
echo "Step 2: Deploying FK Webstack application..."

kubectl apply -f /vagrant/k8s/00-namespace.yaml
status "Namespace created"

# MongoDB
kubectl apply -f /vagrant/k8s/10-mongodb-deployment.yaml
kubectl apply -f /vagrant/k8s/11-mongodb-service.yaml
kubectl apply -f /vagrant/k8s/12-mongodb-init-configmap.yaml
status "MongoDB deployed"

# Wait for MongoDB to be ready before running init job
echo "  Waiting for MongoDB to be ready (max 2 minutes)..."
kubectl wait --for=condition=available deployment/fk-mongodb \
    -n fk-webstack --timeout=120s || warn "MongoDB deployment timeout (may still be starting)"

# MongoDB init job
kubectl apply -f /vagrant/k8s/13-mongodb-init-job.yaml
status "MongoDB init job created"

# API
kubectl apply -f /vagrant/k8s/20-api-deployment.yaml
kubectl apply -f /vagrant/k8s/21-api-service.yaml
kubectl apply -f /vagrant/k8s/22-api-hpa.yaml
status "API deployed with HPA"

# Frontend
kubectl apply -f /vagrant/k8s/30-frontend-deployment.yaml
kubectl apply -f /vagrant/k8s/31-frontend-service.yaml
status "Frontend deployed"

echo ""
echo "Step 3: Installing cert-manager for TLS..."

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "  Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    status "Helm installed"
fi

# Add cert-manager repo if not already added
if ! helm repo list | grep -q jetstack; then
    helm repo add jetstack https://charts.jetstack.io
fi
helm repo update

# Install cert-manager with resource limits
if ! kubectl get namespace cert-manager &>/dev/null; then
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set installCRDs=true \
        --set resources.requests.cpu=100m \
        --set resources.requests.memory=128Mi \
        --set resources.limits.cpu=500m \
        --set resources.limits.memory=512Mi \
        --set webhook.resources.requests.cpu=50m \
        --set webhook.resources.requests.memory=64Mi \
        --set webhook.resources.limits.cpu=200m \
        --set webhook.resources.limits.memory=256Mi \
        --set cainjector.resources.requests.cpu=50m \
        --set cainjector.resources.requests.memory=64Mi \
        --set cainjector.resources.limits.cpu=200m \
        --set cainjector.resources.limits.memory=256Mi \
        --timeout=5m \
        --wait
    status "cert-manager installed"
else
    status "cert-manager already installed"
fi

# Deploy cert issuers
sleep 10  # Give cert-manager time to start webhook
kubectl apply -f /vagrant/k8s/51-selfsigned-issuer.yaml || warn "Failed to create selfsigned issuer (may need manual retry)"

echo ""
echo "Step 4: Installing Prometheus/Grafana monitoring stack..."

# Add prometheus repo if not already added
if ! helm repo list | grep -q prometheus-community; then
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
fi
helm repo update

# Install kube-prometheus-stack with strict resource limits
if ! kubectl get namespace monitoring &>/dev/null; then
    helm install fk-monitoring prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set prometheus.prometheusSpec.resources.requests.cpu=200m \
        --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
        --set prometheus.prometheusSpec.resources.limits.cpu=1000m \
        --set prometheus.prometheusSpec.resources.limits.memory=1Gi \
        --set prometheus.prometheusSpec.retention=6h \
        --set prometheus.prometheusSpec.scrapeInterval=30s \
        --set grafana.resources.requests.cpu=100m \
        --set grafana.resources.requests.memory=128Mi \
        --set grafana.resources.limits.cpu=500m \
        --set grafana.resources.limits.memory=512Mi \
        --set alertmanager.enabled=false \
        --set nodeExporter.resources.requests.cpu=50m \
        --set nodeExporter.resources.requests.memory=64Mi \
        --set nodeExporter.resources.limits.cpu=200m \
        --set nodeExporter.resources.limits.memory=128Mi \
        --set kubeStateMetrics.resources.requests.cpu=50m \
        --set kubeStateMetrics.resources.requests.memory=64Mi \
        --set kubeStateMetrics.resources.limits.cpu=200m \
        --set kubeStateMetrics.resources.limits.memory=128Mi \
        --set grafana.adminPassword=admin \
        --timeout=8m \
        --wait
    status "Prometheus/Grafana installed"
else
    status "Prometheus/Grafana already installed"
fi

echo ""
echo "Step 5: Installing ArgoCD for GitOps..."

# Add ArgoCD repo if not already added
if ! helm repo list | grep -q argo; then
    helm repo add argo https://argoproj.github.io/argo-helm
fi
helm repo update

# Install ArgoCD with resource limits
if ! kubectl get namespace argocd &>/dev/null; then
    helm install argo-cd argo/argo-cd \
        --namespace argocd \
        --create-namespace \
        --set server.resources.requests.cpu=100m \
        --set server.resources.requests.memory=128Mi \
        --set server.resources.limits.cpu=500m \
        --set server.resources.limits.memory=512Mi \
        --set controller.resources.requests.cpu=200m \
        --set controller.resources.requests.memory=256Mi \
        --set controller.resources.limits.cpu=1000m \
        --set controller.resources.limits.memory=1Gi \
        --set repoServer.resources.requests.cpu=100m \
        --set repoServer.resources.requests.memory=128Mi \
        --set repoServer.resources.limits.cpu=500m \
        --set repoServer.resources.limits.memory=512Mi \
        --set redis.resources.requests.cpu=50m \
        --set redis.resources.requests.memory=64Mi \
        --set redis.resources.limits.cpu=200m \
        --set redis.resources.limits.memory=256Mi \
        --set dex.enabled=false \
        --timeout=8m \
        --wait
    status "ArgoCD installed"
    
    # Apply ArgoCD application manifest
    sleep 15
    kubectl apply -f /vagrant/k8s/60-argocd-application.yaml || warn "ArgoCD application manifest failed (may need manual retry)"
else
    status "ArgoCD already installed"
fi

echo ""
echo "======================================"
echo "Deployment Summary"
echo "======================================"
echo ""

# Check application pods
echo "FK Webstack Pods:"
kubectl get pods -n fk-webstack -o wide

echo ""
echo "Monitoring Pods:"
kubectl get pods -n monitoring | grep -E 'NAME|prometheus|grafana|node-exporter' || echo "  No monitoring pods yet"

echo ""
echo "cert-manager Pods:"
kubectl get pods -n cert-manager || echo "  No cert-manager pods yet"

echo ""
echo "ArgoCD Pods:"
kubectl get pods -n argocd | grep -E 'NAME|server|controller|repo' || echo "  No ArgoCD pods yet"

echo ""
echo "======================================"
echo "Access Information"
echo "======================================"
echo ""
echo "API Test (from control plane):"
echo "  kubectl port-forward svc/fk-api -n fk-webstack 8000:8000"
echo "  curl http://localhost:8000/api/name"
echo ""
echo "Grafana Dashboard:"
echo "  kubectl port-forward svc/fk-monitoring-grafana -n monitoring 3000:80"
echo "  Browser: http://localhost:3000"
echo "  Login: admin / admin"
echo ""
echo "ArgoCD UI:"
echo "  kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443"
echo "  Browser: https://localhost:8080"
echo "  Password: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d"
echo ""

status "Deployment complete!"
echo ""
echo "Note: Some pods may take 2-5 minutes to fully start."
echo "Monitor with: kubectl get pods -A -w"
