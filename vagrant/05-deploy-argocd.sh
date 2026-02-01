#!/bin/bash
# Deploy ArgoCD, cert-manager, and FK stack to kubeadm cluster
# Run this AFTER Vagrant cluster is ready

set -e

echo "=== FK Webstack - Kubeadm Deployment ==="

# Wait for cluster to be fully ready
echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready node --all --timeout=300s

echo "Cluster nodes:"
kubectl get nodes

# 1. Install Helm
echo -e "\n[1/5] Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 2. Install cert-manager
echo -e "\n[2/5] Installing cert-manager..."
kubectl create namespace cert-manager 2>/dev/null || true
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true \
  --wait

# 3. Install ArgoCD via Helm
echo -e "\n[3/5] Installing ArgoCD..."
kubectl create namespace argocd 2>/dev/null || true
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Generate secure ArgoCD password if not set
if [ -z "$ARGOCD_ADMIN_PASSWORD" ]; then
  ARGOCD_ADMIN_PASSWORD=$(openssl rand -base64 12)
  echo "⚠️  Generated ArgoCD password: $ARGOCD_ADMIN_PASSWORD"
  echo "⚠️  Store this password securely (NOT in Git)"
  echo "    Hint: echo '$ARGOCD_ADMIN_PASSWORD' > ~/.argocd-password && chmod 600 ~/.argocd-password"
fi

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set configs.secret.argocdServerAdminPassword="$ARGOCD_ADMIN_PASSWORD" \
  --wait

# 4. Deploy cert issuer + FK stack manifests
echo -e "\n[4/5] Deploying FK webstack manifests..."
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/51-selfsigned-issuer.yaml
kubectl apply -f k8s/10-mongodb-deployment.yaml
kubectl apply -f k8s/11-mongodb-service.yaml
kubectl apply -f k8s/12-mongodb-init-configmap.yaml
kubectl apply -f k8s/13-mongodb-init-job.yaml

# Deploy secrets (from .env.local if available)
if [ -f .env.local ]; then
  echo "📝 Deploying secrets from .env.local..."
  export $(cat .env.local | grep -v '^#' | xargs)
  envsubst < k8s/99-secrets-template.yaml | kubectl apply -f -
else
  echo "⚠️  .env.local not found, skipping secret deployment"
  echo "    Create .env.local from .env.local.example"
fi

kubectl apply -f k8s/20-api-deployment.yaml
kubectl apply -f k8s/21-api-service.yaml
kubectl apply -f k8s/22-api-hpa.yaml
kubectl apply -f k8s/30-frontend-deployment.yaml
kubectl apply -f k8s/31-frontend-service.yaml
kubectl apply -f k8s/40-ingress.yaml

# 5. Deploy ArgoCD Application (GitOps)
echo -e "\n[5/5] Deploying ArgoCD Application for GitOps..."
kubectl apply -f k8s/60-argocd-application.yaml

# Wait for pods
echo -e "\nWaiting for FK stack pods..."
sleep 10
kubectl wait --for=condition=ready pod -l app=fk-api -n fk-webstack --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=fk-frontend -n fk-webstack --timeout=120s 2>/dev/null || true

# Summary
echo -e "\n════════════════════════════════════════"
echo "✅ KUBEADM CLUSTER DEPLOYED"
echo "════════════════════════════════════════"

echo -e "\n📊 Cluster Status:"
kubectl get nodes
echo -e "\n🚀 FK Stack Pods:"
kubectl get pods -n fk-webstack

echo -e "\n📈 ArgoCD UI:"
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "  Port-forward: kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "  URL: https://localhost:8080"
echo "  User: admin"
echo "  Password: $ARGOCD_PWD"

echo -e "\n🌐 Application Access:"
echo "  Ensure /etc/hosts has:"
echo "    127.0.0.1 fk.local"
echo "  Then access: https://fk.local (after setting up port-forward or service)"

echo -e "\n✓ Deployment complete!"
