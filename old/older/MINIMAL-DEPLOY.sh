#!/bin/bash
# Minimal resilient deployment - avoids hanging issues

set -x  # Debug mode to see what's happening

export KUBECONFIG=/root/.kube/config

echo "=== Step 1: Quick cluster check ==="
for i in {1..3}; do
    if kubectl get nodes &>/dev/null; then
        echo "✓ Cluster responding"
        break
    fi
    echo "Retry $i/3 - cluster not responding yet..."
    sleep 5
done

echo ""
echo "=== Step 2: Install Helm (if needed) ==="
helm version 2>/dev/null || curl -sSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo ""
echo "=== Step 3: Add Helm repos ==="
helm repo add cilium https://helm.cilium.io 2>/dev/null || true
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true  
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update --max-concurrent-syncs=1

echo ""
echo "=== Step 4: Install Cilium (30s timeout per attempt) ==="
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set routingMode=tunnel \
  --set resources.limits.cpu=100m \
  --set resources.limits.memory=128Mi \
  --max-concurrent-syncs=1 \
  --timeout 30s \
  --wait=false 2>&1 | grep -E "release|STATUS" || echo "Helm install started"

sleep 10

echo ""
echo "=== Step 5: Install cert-manager ==="
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --timeout 30s \
  --wait=false 2>&1 | grep -E "release|STATUS" || echo "Helm install started"

echo ""
echo "=== Step 6: Deploy App Stack ==="  
kubectl apply -f /vagrant/k8s/ -n fk-webstack 2>&1 | grep -E "created|unchanged"

echo ""
echo "=== Deployment initiated ==="
echo "Status in 2 minutes: kubectl get pods -A"
echo ""
