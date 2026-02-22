#!/bin/bash
set -e

echo "======================================"
echo "Installing ArgoCD (GitOps)"
echo "======================================"
echo "Adding argo repository..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

echo "Installing ArgoCD..."
helm install argocd argo/argo-cd \
  -n argocd \
  --create-namespace \
  --wait \
  --timeout 5m

echo ""
echo "Waiting for ArgoCD to be ready..."
sleep 10

echo "Applying ArgoCD application..."
kubectl apply -f /vagrant/k8s/60-argocd-application.yaml

echo ""
echo "ArgoCD status:"
kubectl get pods -n argocd -o wide

echo ""
echo "Get ArgoCD admin password with:"
echo 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d'

echo ""
echo "✅ ArgoCD installed successfully!"
