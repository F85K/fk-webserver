#!/bin/bash
set -e

echo "======================================"
echo "Installing cert-manager (TLS)"
echo "======================================"
echo "Adding jetstack repository..."
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update

echo "Installing cert-manager with CRDs..."
helm install cert-manager jetstack/cert-manager \
  -n cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --wait \
  --timeout 5m

echo ""
echo "Waiting for cert-manager to be ready..."
sleep 10

echo "Cert-manager status:"
kubectl get pods -n cert-manager -o wide

echo ""
echo "✅ cert-manager installed successfully!"
