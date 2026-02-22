#!/bin/bash
# Install Cilium CNI + Helm add-ons (cert-manager, Prometheus, ArgoCD)

set -e

export KUBECONFIG=/root/.kube/config

echo "=== Installing Cilium CNI via Helm ==="
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash 2>&1 | grep -i version || true

helm repo add cilium https://helm.cilium.io
helm repo update

# Install Cilium with minimal resources for our 12GB environment
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set routingMode=tunnel \
  --set tunnelProtocol=vxlan \
  --set resources.limits.cpu=200m \
  --set resources.limits.memory=256Mi \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=128Mi \
  --set operator.resources.limits.cpu=200m \
  --set operator.resources.limits.memory=256Mi \
  --wait \
  --timeout 5m

echo "⏳ Waiting for Cilium to be ready..."
kubectl wait --for=condition=Ready pod -l k8s-app=cilium -n kube-system --timeout=300s || true
sleep 10

echo "✓ Cilium CNI installed"
kubectl get pods -n kube-system | grep cilium | head -5

echo ""
echo "=== Waiting for nodes to be Ready ==="
kubectl wait --for=condition=Ready node --all --timeout=300s
kubectl get nodes

echo ""
echo "=== Installing cert-manager ==="
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --set resources.limits.cpu=100m \
  --set resources.limits.memory=128Mi \
  --wait \
  --timeout 5m

echo "✓ cert-manager installed"
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=300s || true

echo ""
echo "=== Installing Prometheus + Grafana ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.resources.limits.cpu=500m \
  --set prometheus.prometheusSpec.resources.limits.memory=512Mi \
  --set grafana.resources.limits.cpu=200m \
  --set grafana.resources.limits.memory=256Mi \
  --set prometheus-node-exporter.resources.limits.cpu=100m \
  --set prometheus-node-exporter.resources.limits.memory=128Mi \
  --wait \
  --timeout 10m

echo "✓ Prometheus + Grafana installed"
kubectl get pods -n monitoring | head -10

echo ""
echo "=== Installing ArgoCD ==="
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

kubectl create namespace argocd || true

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set server.service.type=ClusterIP \
  --set resources.limits.cpu=200m \
  --set resources.limits.memory=256Mi \
  --wait \
  --timeout 10m

echo "✓ ArgoCD installed"
kubectl get pods -n argocd | head -10

echo ""
echo "=== Deploying Application Stack ==="
kubectl apply -f /vagrant/k8s/ -n fk-webstack
sleep 15

echo ""
echo "=== Cluster Status ==="
kubectl get nodes
kubectl get pods -n fk-webstack
kubectl get pods -n monitoring | head -5
kubectl get pods -n argocd | head -5

echo ""
echo "✅ Full deployment complete!"
