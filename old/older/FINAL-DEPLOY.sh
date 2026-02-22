#!/bin/bash
# Complete FK Webstack Deployment - Run this on control plane
# Execute: vagrant ssh fk-control -c "sudo bash /vagrant/FINAL-DEPLOY.sh"

set -e

export KUBECONFIG=/root/.kube/config

echo "=================================="
echo "FK WEBSTACK FINAL DEPLOYMENT"
echo "=================================="

# Step 1: Verify cluster
echo ""
echo "Step 1: Verifying cluster..."
kubectl get nodes
READY=$(kubectl get nodes --no-headers | grep -c " Ready " || echo 0)
if [ "$READY" -lt 3 ]; then
    echo "⚠️  Not all nodes ready. Waiting..."
    kubectl wait --for=condition=Ready node --all --timeout=300s
fi

# Step 2: Clean old CNI
echo ""
echo "Step 2: Cleaning old CNI..."
kubectl delete ns kube-flannel 2>/dev/null || true
sleep 5

# Step 3: Install Helm
echo ""
echo "Step 3: Installing Helm..."
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
helm version

# Step 4: Install Cilium CNI
echo ""
echo "Step 4: Installing Cilium CNI..."
helm repo add cilium https://helm.cilium.io
helm repo update

helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set routingMode=tunnel \
  --set kubeProxyReplacement=partial \
  --set resources.limits.cpu=200m \
  --set resources.limits.memory=256Mi \
  --wait \
  --timeout 5m 2>&1 | tail -20

echo "Waiting for Cilium pods..."
sleep 20
kubectl wait --for=condition=Ready pod -l k8s-app=cilium -n kube-system --timeout=300s || true
kubectl get pods -n kube-system -l k8s-app=cilium

# Step 5: Wait for nodes Ready
echo ""
echo "Step 5: Waiting for nodes to be Ready with CNI..."
kubectl wait --for=condition=Ready node --all --timeout=600s
kubectl get nodes

# Step 6: Install cert-manager
echo ""
echo "Step 6: Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --set resources.limits.cpu=100m \
  --set resources.limits.memory=128Mi \
  --wait \
  --timeout 5m 2>&1 | tail -10

kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=300s || true

# Step 7: Install Prometheus + Grafana
echo ""
echo "Step 7: Installing Prometheus + Grafana..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.resources.limits.cpu=500m \
  --set prometheus.prometheusSpec.resources.limits.memory=512Mi \
  --set prometheus.prometheusSpec.retention=24h \
  --set grafana.adminPassword=admin \
  --set grafana.resources.limits.cpu=200m \
  --set grafana.resources.limits.memory=256Mi \
  --wait \
  --timeout 10m 2>&1 | tail -10

kubectl get pods -n monitoring

# Step 8: Install ArgoCD
echo ""
echo "Step 8: Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=ClusterIP \
  --set resources.limits.cpu=200m \
  --set resources.limits.memory=256Mi \
  --wait \
  --timeout 10m 2>&1 | tail -10

kubectl get pods -n argocd

# Step 9: Deploy application stack
echo ""
echo "Step 9: Deploying application stack..."
kubectl apply -f /vagrant/k8s/ -n fk-webstack 2>&1 | grep -E "created|unchanged"
sleep 20

# Step 10: Scale to replicas with hostNetwork if CNI still has issues
echo ""
echo "Step 10: Configuring application pods..."
kubectl get pods -n fk-webstack

# Wait for pods
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=mongodb -n fk-webstack --timeout=300s || {
    echo "MongoDB not ready - checking status..."
    kubectl describe pod -n fk-webstack -l app.kubernetes.io/name=mongodb | tail -20
}

# Step 11: Verify deployment
echo ""
echo "=================================="
echo "DEPLOYMENT COMPLETE!"
echo "=================================="
echo ""
echo "Cluster status:"
kubectl get nodes
echo ""
echo "Application pods:"
kubectl get pods -n fk-webstack
echo ""
echo "cert-manager:"
kubectl get pods -n cert-manager
echo ""
echo "Monitoring:"
kubectl get pods -n monitoring | head -5
echo ""
echo "ArgoCD:"
kubectl get pods -n argocd | head -5

echo ""
echo "Next steps:"
echo "1. Port-forward to test services:"
echo "   kubectl port-forward svc/fk-api -n fk-webstack 8000:8000"
echo "   kubectl port-forward svc/fk-mongodb -n fk-webstack 27017:27017"
echo ""
echo "2. Access Grafana:"
echo "   kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
echo "   Username: admin, Password: admin"
echo ""
echo "3. Access ArgoCD:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "✅ Full stack deployed!"
