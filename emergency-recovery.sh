#!/bin/bash
set -e

echo "======================================"
echo "EMERGENCY RECOVERY: Freeing resources"
echo "======================================"

echo ""
echo "Step 1: Delete incomplete/broken installations..."
# Remove broken ArgoCD
helm uninstall argocd -n argocd 2>/dev/null || echo "ArgoCD not installed"
kubectl delete namespace argocd 2>/dev/null || echo "argocd namespace not found"

# Scale down cert-manager to save resources
echo "Scaling down cert-manager..."
kubectl scale deployment cert-manager -n cert-manager --replicas=1 2>/dev/null || echo "cert-manager not found"
kubectl scale deployment cert-manager-cainjector -n cert-manager --replicas=0 2>/dev/null || echo "cainjector not found"
kubectl scale deployment cert-manager-webhook -n cert-manager --replicas=0 2>/dev/null || echo "webhook not found"

echo ""
echo "Step 2: Wait for pods to stabilize..."
sleep 10

echo ""
echo "Step 3: Clean up fk-webstack namespace..."
# Delete and recreate namespace to clear everything
kubectl delete namespace fk-webstack 2>/dev/null || echo "Namespace delete started"
sleep 5
kubectl create namespace fk-webstack || echo "fk-webstack namespace exists"

echo ""
echo "Step 4: Redeploy core application stack..."
kubectl apply -f /vagrant/k8s/00-namespace.yaml
sleep 2
kubectl apply -f /vagrant/k8s/10-mongodb-deployment.yaml
sleep 10
kubectl apply -f /vagrant/k8s/13-mongodb-init-job.yaml
sleep 5
kubectl apply -f /vagrant/k8s/20-api-deployment.yaml
sleep 5
kubectl apply -f /vagrant/k8s/21-api-service.yaml
sleep 2
kubectl apply -f /vagrant/k8s/30-frontend-deployment.yaml
sleep 2
kubectl apply -f /vagrant/k8s/31-frontend-service.yaml

echo ""
echo "Step 5: Wait for pods to start..."
sleep 30

echo ""
echo "======================================"
echo "FINAL STATUS"
echo "======================================"
kubectl get nodes
echo ""
kubectl get pods -n fk-webstack -o wide
echo ""
echo "Waiting for pods to be ready..."
sleep 20
echo ""
kubectl get pods -n fk-webstack -o wide

echo ""
echo "✅ Recovery complete!"
echo "Next: Test with port-forward"
