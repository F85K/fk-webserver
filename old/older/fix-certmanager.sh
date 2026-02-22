#!/bin/bash
set -e

echo "======================================"
echo "Fixing cert-manager installation"
echo "======================================"

# First, check if it's already installed
if helm list -n cert-manager 2>/dev/null | grep -q cert-manager; then
    echo "cert-manager found, checking status..."
    kubectl get pods -n cert-manager
    echo "✅ cert-manager appears to be installed"
    exit 0
fi

echo "Installing cert-manager without waiting for startup check..."
helm install cert-manager jetstack/cert-manager \
  -n cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --set global.leaderElection.namespace=cert-manager 2>&1 | grep -v "post-install" || true

echo ""
echo "Waiting 30 seconds for cert-manager pods to start..."
sleep 30

echo ""
echo "cert-manager pod status:"
kubectl get pods -n cert-manager -o wide 2>/dev/null || echo "Pods not ready yet"

echo ""
echo "Waiting another 30 seconds..."
sleep 30

echo "Final cert-manager status:"
kubectl get pods -n cert-manager -o wide

# Verify key components are running
if kubectl get pods -n cert-manager 2>/dev/null | grep -q "cert-manager.*Running"; then
    echo ""
    echo "✅ cert-manager is running!"
else
    echo ""
    echo "⚠️ cert-manager pods not yet running, they may still be starting"
fi
