#!/bin/bash
# Quick verification
echo "Namespaces:"
kubectl get ns --no-headers

echo ""
echo "cert-manager:"
kubectl get pods -n cert-manager --no-headers 2>/dev/null || echo "Not found"

echo ""
echo "argocd:"
kubectl get pods -n argocd --no-headers 2>/dev/null || echo "Not found"

echo ""
echo "fk-webstack:"
kubectl get pods -n fk-webstack --no-headers

echo ""
echo "All services:"
kubectl get svc -A --no-headers | grep -E "fk-api|argocd|cert-manager" || echo "Services status checked"
