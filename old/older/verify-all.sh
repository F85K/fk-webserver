#!/bin/bash
set -e

echo "======================================"
echo "Final Installation Verification"
echo "======================================"

echo ""
echo "📦 Checking all namespaces..."
kubectl get ns

echo ""
echo "🔐 cert-manager pods:"
kubectl get pods -n cert-manager -o wide

echo ""
echo "🔄 ArgoCD pods:"
kubectl get pods -n argocd -o wide

echo ""
echo "🌐 Application pods (fk-webstack):"
kubectl get pods -n fk-webstack -o wide

echo ""
echo "📋 All services:"
kubectl get svc -A

echo ""
echo "======================================"
echo "✅ Installation Summary"
echo "======================================"
echo ""
echo "Feature Status:"
echo "  ✅ cert-manager (TLS): $(kubectl get pods -n cert-manager 2>/dev/null | grep -c Running) pods Running"
echo "  ✅ ArgoCD (GitOps): $(kubectl get pods -n argocd 2>/dev/null | grep -c Running) pods Running"
echo "  ✅ Application: $(kubectl get pods -n fk-webstack 2>/dev/null | grep -c Running) pods Running"

echo ""
echo "Next: Test the API!"
echo "1. In NEW terminal 1, run:"
echo "   vagrant ssh fk-control -c 'kubectl port-forward svc/fk-api -n fk-webstack 8000:8000'"
echo ""
echo "2. In NEW terminal 2, run:"
echo "   Invoke-RestMethod http://localhost:8000/api/name"
echo ""
echo "Expected result: {\"name\":\"Frank Koch\"}"
