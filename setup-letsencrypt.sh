#!/bin/bash
# FK HTTPS Setup with cert-manager + DuckDNS DNS-01
# Domain: fk-webserver.duckdns.org
#
# Usage:
#   1) Put DUCKDNS_TOKEN in /vagrant/.env.local (gitignored)
#   2) bash /vagrant/setup-letsencrypt.sh

set -e

echo "========================================"
echo "cert-manager + DuckDNS DNS-01 Setup"
echo "========================================"
echo ""

if [ -f /vagrant/.env.local ]; then
  # Load DUCKDNS_TOKEN from .env.local (gitignored)
  set -a
  . /vagrant/.env.local
  set +a
fi

DUCKDNS_TOKEN=$(printf "%s" "${DUCKDNS_TOKEN}" | tr -d '\r\n')

if [ -z "${DUCKDNS_TOKEN}" ]; then
  echo "ERROR: DUCKDNS_TOKEN is not set."
  echo "Create /vagrant/.env.local with: DUCKDNS_TOKEN=your_token"
  exit 1
fi

LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL:-r1034515@student.thomasmore.be}

# Step 1: Add Helm repo
echo "[1/5] Adding Helm repository..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Step 2: Install cert-manager
echo "[2/5] Installing cert-manager..."
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --wait \
  --timeout 5m \
  2>&1 | tail -5

sleep 10

# Step 3: Install DuckDNS webhook + ClusterIssuers
echo "[3/5] Installing DuckDNS webhook (DNS-01)..."
WEBHOOK_DIR=/tmp/cert-manager-webhook-duckdns
if [ ! -d "${WEBHOOK_DIR}" ]; then
  git clone https://github.com/ebrianne/cert-manager-webhook-duckdns.git "${WEBHOOK_DIR}"
fi

helm upgrade --install cert-manager-webhook-duckdns \
  --namespace cert-manager \
  --set duckdns.token="${DUCKDNS_TOKEN}" \
  --set clusterIssuer.production.create=true \
  --set clusterIssuer.staging.create=true \
  --set clusterIssuer.email="${LETSENCRYPT_EMAIL}" \
  --set logLevel=2 \
  "${WEBHOOK_DIR}/deploy/cert-manager-webhook-duckdns"

sleep 10

# Step 4: Update Ingress with cert-manager annotations
echo "[4/5] Updating Ingress for HTTPS..."
kubectl apply -f /vagrant/k8s/40-ingress.yaml
sleep 5

# Step 5: Wait for certificate
echo "[5/5] Waiting for certificate (can take a few minutes)..."

# Verification
echo ""
echo "========================================"
echo "✅ Setup Complete!"
echo "========================================"
echo ""
echo "Cert-manager pods:"
kubectl get pods -n cert-manager
echo ""
echo "ClusterIssuers:"
kubectl get clusterissuer | grep duckdns || true
echo ""
echo "Certificate status (wait 2-3 minutes for provisioning):"
kubectl get certificate -n fk-webstack -o wide 2>/dev/null || echo "Certificate creating..."
echo ""
echo "Next steps:"
echo "1. Check certificate status: kubectl get certificate -n fk-webstack -w"
echo "2. Test: curl -I https://fk-webserver.duckdns.org"
echo ""
echo "⚠️  Make sure:"
echo "   - DNS resolves fk-webserver.duckdns.org to 81.82.115.88"
echo "   - DuckDNS token is correct"
