#!/bin/bash

################################################################################
# FK Webserver - Complete Stack Deployment Script
# Purpose: Deploy all components with proper sequencing and wait times
# Duration: 45-60 minutes (safe for unattended execution)
# 
# Phases:
#   1. Pre-flight checks (30s)
#   2. Core app deployment (12-15 min)
#   3. Ingress-NGINX (4-6 min)
#   4. cert-manager + Let's Encrypt (8-15 min)
#   5. Prometheus + Grafana (6-12 min)
#   6. ArgoCD + GitOps (8-12 min)
#   7. Metrics Server + HPA (4-8 min)
################################################################################

set -e

# Fix kubectl PATH and kubeconfig
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin
export KUBECONFIG=/root/.kube/config

# Load environment variables from .env.local (DuckDNS token, Let's Encrypt email)
if [ -f /vagrant/.env.local ]; then
    # Strip Windows line endings (\r) from .env.local before sourcing
    export $(grep -v '^#' /vagrant/.env.local | tr -d '\r' | xargs)
else
    warning "⚠️  .env.local not found. If using DuckDNS, create it in workspace root with DUCKDNS_TOKEN and LETSENCRYPT_EMAIL"
fi

# Use full path to kubectl (apt installs to /usr/bin)
KUBECTL=/usr/bin/kubectl

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LOG_FILE="/tmp/deployment-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"
}

################################################################################
# PHASE -1: Kubernetes Cluster Initialization (if needed)
################################################################################

log "════════════════════════════════════════════════════════════════════════════════"
log "PHASE -1: Checking Kubernetes Cluster Status"
log "════════════════════════════════════════════════════════════════════════════════"

# Check if base setup was done
if [ ! -f /etc/containerd/config.toml ]; then
    log "Running base setup (Docker, containerd, iptables, etc)..."
    sudo bash /vagrant/vagrant/01-base-setup.sh || error "Failed to run base setup"
    
    log "Waiting 30 seconds for containerd to start..."
    sleep 30
fi

# Verify containerd is running
if ! sudo test -S /var/run/containerd/containerd.sock; then
    error "Containerd socket not found - containerd may not be running"
    sudo systemctl restart containerd
    sleep 10
fi

success "Containerd is ready"

# Check if kubectl exists
if [ ! -f "$KUBECTL" ]; then
    log "kubectl not found - installing Kubernetes..."
    log "Installing kubeadm, kubelet, kubectl..."
    sudo bash /vagrant/vagrant/02-kubeadm-install.sh || error "Failed to install kubeadm"
    
    log "Waiting 30 seconds for kubectl to be available..."
    sleep 30
    
    # Check if we're on control plane or worker
    if [ -f /vagrant/vagrant/03-control-plane-init.sh ]; then
        log "Initializing control plane..."
        sudo bash /vagrant/vagrant/03-control-plane-init.sh || error "Failed to init control plane"
        
        log "Waiting 120 seconds for control plane and kubelet to stabilize..."
        sleep 120
        
        # Wait for API server to be responsive
        log "Waiting for Kubernetes API server to be ready..."
        max_wait=300
        elapsed=0
        while ! "$KUBECTL" cluster-info &>/dev/null && [ $elapsed -lt $max_wait ]; do
            echo -n "."
            sleep 10
            elapsed=$((elapsed + 10))
        done
        
        if [ $elapsed -ge $max_wait ]; then
            warning "API server took longer than expected to start (continuing anyway)"
        else
            success "API server is ready"
        fi
    fi
fi

# Verify kubectl is now available
if [ ! -f "$KUBECTL" ]; then
    error "kubectl still not found after initialization"
    exit 1
fi

success "Kubernetes cluster is ready"
sleep 5

wait_for_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=${3:-"default"}
    local max_attempts=${4:-60}
    local sleep_interval=${5:-10}
    
    log "Waiting for $resource_type/$resource_name to be ready..."
    
    for ((i=1; i<=max_attempts; i++)); do
        if "$KUBECTL" get "$resource_type" "$resource_name" -n "$namespace" &>/dev/null; then
            if "$KUBECTL" wait --for=condition=ready "$resource_type" "$resource_name" -n "$namespace" --timeout=30s 2>/dev/null; then
                success "$resource_type/$resource_name is ready"
                return 0
            fi
        fi
        echo -n "."
        sleep "$sleep_interval"
    done
    
    warning "$resource_type/$resource_name did not become ready in time (continuing anyway)"
    return 0
}

wait_for_deployment() {
    local deployment=$1
    local namespace=${2:-"default"}
    local max_attempts=${3:-120}
    
    log "Waiting for deployment $deployment to have ready replicas..."
    
    for ((i=1; i<=max_attempts; i++)); do
        local ready=$("$KUBECTL" get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired=$("$KUBECTL" get deployment "$deployment" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        
        if [[ "$ready" == "$desired" ]] && [[ "$desired" != "0" ]]; then
            success "Deployment $deployment ready: $ready/$desired replicas"
            return 0
        fi
        
        echo -n "."
        sleep 10
    done
    
    warning "Deployment $deployment did not reach desired replicas in time (continuing anyway)"
    return 0
}

wait_for_nodes_ready() {
    local max_wait=${1:-300}
    local elapsed=0

    log "Waiting for nodes to become Ready..."
    while [ $elapsed -lt $max_wait ]; do
        local ready_count=$("$KUBECTL" get nodes --no-headers 2>/dev/null | awk '$2=="Ready"{count++} END {print count+0}')
        if [ "$ready_count" -ge 1 ]; then
            success "Nodes Ready: $ready_count"
            return 0
        fi
        echo -n "."
        sleep 10
        elapsed=$((elapsed + 10))
    done

    warning "Nodes did not become Ready in time (continuing anyway)"
    return 0
}

################################################################################
# PHASE 0: Pre-flight Verification
################################################################################

log "════════════════════════════════════════════════════════════════════════════════"
log "PHASE -0.5: CNI Setup (Flannel)"
log "════════════════════════════════════════════════════════════════════════════════"

if ! "$KUBECTL" -n kube-flannel get ds kube-flannel-ds &>/dev/null; then
    log "Installing Flannel CNI..."
    "$KUBECTL" apply -f https://raw.githubusercontent.com/flannel-io/flannel/v0.25.1/Documentation/kube-flannel.yml
else
    log "Flannel already installed"
fi

log "Waiting for Flannel to be ready..."
"$KUBECTL" -n kube-flannel rollout status ds/kube-flannel-ds --timeout=5m || warning "Flannel rollout timed out"
wait_for_nodes_ready 300

log "════════════════════════════════════════════════════════════════════════════════"
log "PHASE 0: Pre-flight Verification"
log "════════════════════════════════════════════════════════════════════════════════"

# Check kubectl
if ! [ -f "$KUBECTL" ] || ! "$KUBECTL" version &> /dev/null; then
    error "kubectl not accessible at $KUBECTL"
    exit 1
fi

# Check cluster status
log "Verifying cluster status..."
"$KUBECTL" cluster-info || {
    error "Cluster is not accessible"
    exit 1
}

# Check nodes
NODE_COUNT=$("$KUBECTL" get nodes --no-headers 2>/dev/null | wc -l)
if [ "$NODE_COUNT" -lt 1 ]; then
    warning "No nodes found (cluster may still be initializing)"
else
    success "Found $NODE_COUNT nodes"
fi

if [ "$NODE_COUNT" -eq 1 ]; then
    log "Single-node cluster detected; allowing workloads on control-plane node..."
    "$KUBECTL" taint nodes --all node-role.kubernetes.io/control-plane- || true
    "$KUBECTL" taint nodes --all node-role.kubernetes.io/master- || true
fi

# Show nodes
log "Cluster nodes:"
"$KUBECTL" get nodes --no-headers | awk '{print "  " $1, "(" $2 ")"}'

sleep 5

################################################################################
# PHASE 1: Core Application Deployment
################################################################################

log "════════════════════════════════════════════════════════════════════════════════"
log "PHASE 1: Core Application Deployment (MongoDB, API, Frontend)"
log "════════════════════════════════════════════════════════════════════════════════"

log "Deploying namespace..."
"$KUBECTL" apply -f /vagrant/k8s/00-namespace.yaml

log "Deploying MongoDB..."
"$KUBECTL" apply -f /vagrant/k8s/08-mongodb-pv.yaml
"$KUBECTL" apply -f /vagrant/k8s/09-mongodb-pvc.yaml
"$KUBECTL" apply -f /vagrant/k8s/10-mongodb-deployment.yaml
"$KUBECTL" apply -f /vagrant/k8s/11-mongodb-service.yaml
"$KUBECTL" apply -f /vagrant/k8s/12-mongodb-init-configmap.yaml
sleep 30

log "Waiting for MongoDB pod to be ready (this takes 2-3 minutes)..."
wait_for_deployment "fk-mongodb" "fk-webstack" 180

log "Running MongoDB initialization job..."
"$KUBECTL" apply -f /vagrant/k8s/13-mongodb-init-job.yaml
sleep 60

log "Deploying FastAPI backend..."
"$KUBECTL" apply -f /vagrant/k8s/20-api-deployment.yaml
"$KUBECTL" apply -f /vagrant/k8s/21-api-service.yaml
sleep 30

log "Waiting for API deployment to have ready replicas (2-3 minutes)..."
wait_for_deployment "fk-api" "fk-webstack" 180

log "Deploying lighttpd frontend..."
"$KUBECTL" apply -f /vagrant/k8s/30-frontend-deployment.yaml
"$KUBECTL" apply -f /vagrant/k8s/31-frontend-service.yaml
sleep 30

log "Waiting for frontend deployment..."
wait_for_deployment "fk-frontend" "fk-webstack" 120

success "Core application deployed"
sleep 60

################################################################################
# PHASE 2: Ingress Controller
################################################################################

log "════════════════════════════════════════════════════════════════════════════════"
log "PHASE 2: Ingress Controller (NGINX/Traefik)"
log "════════════════════════════════════════════════════════════════════════════════"

log "Installing NGINX Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.hostNetwork=true \
    --set controller.kind=DaemonSet \
    --set controller.daemonset.useHostPort=true \
    --set service.type=ClusterIP

log "Waiting for NGINX Ingress Controller daemonset to be ready..."
$KUBECTL -n ingress-nginx rollout status ds/ingress-nginx-controller --timeout=5m || warning "NGINX daemonset status timed out"

success "NGINX Ingress Controller installed"
sleep 30

################################################################################
# PHASE 3: Certificate Manager + Let's Encrypt
################################################################################

log "════════════════════════════════════════════════════════════════════════════════"
log "PHASE 3: Certificate Manager + Let's Encrypt (DNS-01)"
log "════════════════════════════════════════════════════════════════════════════════"

log "Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --set installCRDs=true

log "Waiting for cert-manager webhook to be ready..."
wait_for_deployment "cert-manager-webhook" "cert-manager" 120

log "Creating self-signed ClusterIssuer..."
"$KUBECTL" apply -f /vagrant/k8s/51-selfsigned-issuer.yaml

log "Installing DuckDNS webhook for DNS-01 validation..."
if [ -z "$DUCKDNS_TOKEN" ]; then
    warning "DUCKDNS_TOKEN not set - DuckDNS DNS-01 validation will not work"
    warning "Create .env.local in workspace root with: DUCKDNS_TOKEN=your_token"
else
    log "DUCKDNS_TOKEN is set, installing webhook from GitHub repository..."
    
    # Create DuckDNS token secret in cert-manager namespace
    # Create DuckDNS token secret, stripping any carriage returns from the token
    "$KUBECTL" create secret generic duckdns-token --from-literal=token="$(echo -n "$DUCKDNS_TOKEN" | tr -d '\r')" -n cert-manager --dry-run=client -o yaml | "$KUBECTL" apply -f -
    success "DuckDNS token secret created"
    
    # Clone DuckDNS webhook from GitHub and install locally
    cd /tmp
    if [ -d cert-manager-webhook-duckdns ]; then
        log "DuckDNS webhook already cloned, updating..."
        cd cert-manager-webhook-duckdns
        git pull origin main 2>/dev/null || true
        cd /tmp
    else
        log "Cloning DuckDNS webhook repository..."
        git clone https://github.com/ebrianne/cert-manager-webhook-duckdns.git || error "Failed to clone DuckDNS webhook repository"
    fi
    
    log "Installing cert-manager-webhook-duckdns from local chart..."
    helm upgrade --install cert-manager-webhook-duckdns \
        /tmp/cert-manager-webhook-duckdns/deploy/cert-manager-webhook-duckdns \
        --namespace cert-manager \
        --set duckdns.domain=fk-webserver.duckdns.org \
        --set "duckdns.token=$(echo -n "$DUCKDNS_TOKEN" | tr -d '\r')"
    
    success "DuckDNS webhook installed"
    
    log "Waiting for DuckDNS webhook pod to be ready..."
    sleep 30
    "$KUBECTL" -n cert-manager rollout status deployment/cert-manager-webhook-duckdns --timeout=5m || warning "DuckDNS webhook deployment timed out"
fi

log "Creating Let's Encrypt ClusterIssuer (DNS-01 with DuckDNS)..."
# Create ClusterIssuer with correct API group (acme.duckdns.org) for DNS-01 validation
cat <<EOFISSUER | "$KUBECTL" apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cert-manager-webhook-duckdns-production
spec:
  acme:
    email: $LETSENCRYPT_EMAIL
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-duckdns-key
    solvers:
      - dns01:
          webhook:
            groupName: acme.duckdns.org
            solverName: duckdns
            config:
              tokenSecretRef:
                name: duckdns-token
                key: token
EOFISSUER

success "Certificate manager installed"
sleep 120

################################################################################
# PHASE 4: Ingress with TLS/HTTPS
################################################################################

log "════════════════════════════════════════════════════════════════════════════════"
log "PHASE 4: Ingress with TLS/HTTPS Certificate"
log "════════════════════════════════════════════════════════════════════════════════"

log "Creating ingress with TLS certificate..."
"$KUBECTL" apply -f /vagrant/k8s/40-ingress.yaml

log "Waiting for certificate to be ready (this can take 5-10 minutes for DNS-01 validation)..."
for i in {1..300}; do
    if "$KUBECTL" get certificate -n fk-webstack fk-webserver-tls-cert -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
        success "Certificate is ready"
        break
    fi
    echo -n "."
    sleep 2
done

log "Certificate status:"
"$KUBECTL" describe certificate fk-webserver-tls-cert -n fk-webstack 2>/dev/null | tail -20 || warning "Certificate not yet ready"

log "Checking ACME orders:"
"$KUBECTL" get orders -n fk-webstack 2>/dev/null || log "No ACME orders found yet"

success "Ingress with TLS configured"
sleep 60

################################################################################
# PHASE 5: Monitoring (Prometheus + Grafana)
################################################################################

log "════════════════════════════════════════════════════════════════════════════════"
log "PHASE 5: Monitoring Stack (Prometheus + Grafana)"
log "════════════════════════════════════════════════════════════════════════════════"

log "Adding Prometheus Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

log "Installing kube-prometheus-stack..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    --set prometheus.prometheusSpec.retention=24h \
    --set grafana.adminPassword=admin \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

log "Waiting for Prometheus..."
wait_for_deployment "prometheus-kube-prometheus-prometheus" "monitoring" 120

log "Waiting for Grafana..."
wait_for_deployment "prometheus-grafana" "monitoring" 120

success "Monitoring stack deployed"
sleep 120

################################################################################
# PHASE 6: ArgoCD GitOps
################################################################################

log "════════════════════════════════════════════════════════════════════════════════"
log "PHASE 6: ArgoCD GitOps Integration"
log "════════════════════════════════════════════════════════════════════════════════"

log "Adding ArgoCD Helm repo..."
helm repo add argocd https://argoproj.github.io/argo-helm
helm repo update

log "Installing ArgoCD..."
helm upgrade --install argocd argocd/argo-cd \
    --namespace argocd \
    --create-namespace \
    --set server.insecure=true

log "Waiting for ArgoCD server..."
wait_for_deployment "argocd-server" "argocd" 120

log "Waiting for ArgoCD application controller..."
wait_for_deployment "argocd-application-controller" "argocd" 120

log "Creating ArgoCD application..."
"$KUBECTL" apply -f /vagrant/k8s/60-argocd-application.yaml

log "Getting initial ArgoCD admin password..."
ARGOCD_PASSWORD=$("$KUBECTL" get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
log "ArgoCD admin password: $ARGOCD_PASSWORD"

success "ArgoCD deployed and configured"
sleep 120

################################################################################
# PHASE 7: Metrics Server + HPA
################################################################################

log "════════════════════════════════════════════════════════════════════════════════"
log "PHASE 7: Metrics Server + Horizontal Pod Autoscaler"
log "════════════════════════════════════════════════════════════════════════════════"

log "Installing Metrics Server..."
"$KUBECTL" apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

log "Waiting for metrics-server..."
wait_for_deployment "metrics-server" "kube-system" 120

log "Deploying HPA for API..."
"$KUBECTL" apply -f /vagrant/k8s/22-api-hpa.yaml

log "Verifying HPA status..."
"$KUBECTL" get hpa -n default

success "Metrics Server and HPA deployed"
sleep 60

################################################################################
# Final Verification
################################################################################

log "════════════════════════════════════════════════════════════════════════════════"
log "FINAL VERIFICATION"
log "════════════════════════════════════════════════════════════════════════════════"

log "Cluster nodes:"
"$KUBECTL" get nodes -o wide

log "All pods across cluster:"
"$KUBECTL" get pods -A --no-headers | grep -E "Running|Pending" | awk '{print $1, $2, $3, $4}'

log "Deployments status:"
"$KUBECTL" get deployments -A --no-headers

log "Services:"
"$KUBECTL" get svc -A --no-headers | head -20

log "Certificates:"
"$KUBECTL" get certificates -A --no-headers

log "Ingress:"
"$KUBECTL" get ingress -A --no-headers

log "HPA Status:"
"$KUBECTL" get hpa -A --no-headers

################################################################################
# Summary
################################################################################

success "════════════════════════════════════════════════════════════════════════════════"
success "✓ DEPLOYMENT COMPLETE"
success "════════════════════════════════════════════════════════════════════════════════"

log ""
log "📊 Monitoring Stack:"
log "   • Prometheus: http://prometheus.internal or via NGINX ingress"
log "   • Grafana: http://grafana.internal or via NGINX ingress (admin/admin)"
log ""
log "🔐 Application:"
log "   • Frontend: https://fk-webserver.duckdns.org"
log "   • API: https://fk-webserver.duckdns.org/api"
log "   • API Docs: https://fk-webserver.duckdns.org/api/docs"
log ""
log "🚀 GitOps:"
log "   • ArgoCD: http://argocd.internal or via port-forward"
log "   • ArgoCD Password: $ARGOCD_PASSWORD"
log ""
log "📈 Auto-scaling:"
log "   • HPA configured (3-10 replicas, 80% CPU target)"
log ""
log "📝 Deployment log: $LOG_FILE"
log ""

success "All components deployed successfully!"
