#!/bin/bash
set -e

echo "==== Installing ArgoCD ===="
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  -n argocd \
  --create-namespace

echo "==== Waiting for ArgoCD to be ready ===="
sleep 15

echo "==== Applying ArgoCD Application ===="
kubectl apply -f /vagrant/k8s/60-argocd-application.yaml

echo "==== Checking ArgoCD pods ===="
kubectl get pods -n argocd

echo "✅ ArgoCD installed!"
echo ""
echo "Get ArgoCD admin password:"
echo 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d'
