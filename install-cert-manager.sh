#!/bin/bash
set -e

echo "==== Installing cert-manager ===="
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  -n cert-manager \
  --create-namespace \
  --set installCRDs=true

echo "==== Waiting for cert-manager to be ready ===="
sleep 10
kubectl get pods -n cert-manager

echo "✅ cert-manager installed!"
