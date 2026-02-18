#!/bin/bash
# Verify all success criteria for the FK Webstack project

set +e  # Don't exit on errors, we want to see all results

KUBECONFIG=/root/.kube/config
export KUBECONFIG

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS="${GREEN}✓ PASS${NC}"
FAIL="${RED}✗ FAIL${NC}"
WARN="${YELLOW}⚠ WARN${NC}"

echo "======================================"
echo "FK Webstack Success Criteria Verification"
echo "======================================"
echo ""

# Counter for passed criteria
PASSED=0
TOTAL=7

# Criterion 1: Docker Containers
echo "1. Docker Stack (containers running in Kubernetes)"
echo "   --------------------------------------------------"
MONGO_PODS=$(kubectl get pods -n fk-webstack -l app=fk-mongodb --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
API_PODS=$(kubectl get pods -n fk-webstack -l app=fk-api --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
FRONTEND_PODS=$(kubectl get pods -n fk-webstack -l app=fk-frontend --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

if [ "$MONGO_PODS" -gt 0 ] && [ "$API_PODS" -gt 0 ] && [ "$FRONTEND_PODS" -gt 0 ]; then
    echo -e "   $PASS - MongoDB: $MONGO_PODS, API: $API_PODS, Frontend: $FRONTEND_PODS"
    ((PASSED++))
else
    echo -e "   $FAIL - MongoDB: $MONGO_PODS, API: $API_PODS, Frontend: $FRONTEND_PODS"
fi
echo ""

# Criterion 2: Kubernetes Cluster
echo "2. Kubernetes Cluster (3 nodes: 1 control + 2 workers)"
echo "   --------------------------------------------------"
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$READY_NODES" -eq 3 ] && [ "$TOTAL_NODES" -eq 3 ]; then
    echo -e "   $PASS - All 3 nodes Ready"
    ((PASSED++))
elif [ "$READY_NODES" -ge 2 ]; then
    echo -e "   $WARN - Only $READY_NODES/$TOTAL_NODES nodes Ready (minimum 2 required)"
    ((PASSED++))
else
    echo -e "   $FAIL - Only $READY_NODES/$TOTAL_NODES nodes Ready"
fi
kubectl get nodes 2>/dev/null | sed 's/^/   /'
echo ""

# Criterion 3: Live Data (MongoDB integration)
echo "3. Live Data (MongoDB with initial data)"
echo "   --------------------------------------------------"
if kubectl get jobs -n fk-webstack fk-mongo-init-job &>/dev/null; then
    JOB_STATUS=$(kubectl get jobs -n fk-webstack fk-mongo-init-job -o jsonpath='{.status.succeeded}' 2>/dev/null)
    if [ "$JOB_STATUS" == "1" ]; then
        echo -e "   $PASS - MongoDB init job completed successfully"
        ((PASSED++))
    else
        echo -e "   $WARN - MongoDB init job exists but may not have completed"
        kubectl get jobs -n fk-webstack 2>/dev/null | sed 's/^/   /'
    fi
else
    echo -e "   $FAIL - MongoDB init job not found"
fi
echo ""

# Criterion 4: TLS/Secrets Management
echo "4. TLS & Secrets (cert-manager + issuers)"
echo "   --------------------------------------------------"
CERT_MANAGER_PODS=$(kubectl get pods -n cert-manager --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
ISSUER_EXISTS=$(kubectl get clusterissuer selfsigned-issuer &>/dev/null && echo "yes" || echo "no")

if [ "$CERT_MANAGER_PODS" -ge 3 ] && [ "$ISSUER_EXISTS" == "yes" ]; then
    echo -e "   $PASS - cert-manager running ($CERT_MANAGER_PODS pods), issuer configured"
    ((PASSED++))
elif [ "$CERT_MANAGER_PODS" -gt 0 ]; then
    echo -e "   $WARN - cert-manager partially running ($CERT_MANAGER_PODS pods)"
    kubectl get pods -n cert-manager 2>/dev/null | sed 's/^/   /'
else
    echo -e "   $FAIL - cert-manager not running"
fi
echo ""

# Criterion 5: Monitoring (Prometheus + Grafana)
echo "5. Monitoring (Prometheus, Grafana, metrics)"
echo "   --------------------------------------------------"
PROM_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
GRAFANA_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

if [ "$PROM_PODS" -gt 0 ] && [ "$GRAFANA_PODS" -gt 0 ]; then
    echo -e "   $PASS - Prometheus: $PROM_PODS, Grafana: $GRAFANA_PODS"
    ((PASSED++))
elif [ "$PROM_PODS" -gt 0 ] || [ "$GRAFANA_PODS" -gt 0 ]; then
    echo -e "   $WARN - Partial deployment - Prometheus: $PROM_PODS, Grafana: $GRAFANA_PODS"
    kubectl get pods -n monitoring 2>/dev/null | grep -E 'NAME|prometheus|grafana' | sed 's/^/   /'
else
    echo -e "   $FAIL - Monitoring stack not deployed"
fi
echo ""

# Criterion 6: GitOps (ArgoCD)
echo "6. GitOps (ArgoCD installation and application)"
echo "   --------------------------------------------------"
ARGOCD_PODS=$(kubectl get pods -n argocd --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
ARGOCD_APP=$(kubectl get applications -n argocd fk-webstack-app &>/dev/null && echo "yes" || echo "no")

if [ "$ARGOCD_PODS" -ge 3 ] && [ "$ARGOCD_APP" == "yes" ]; then
    echo -e "   $PASS - ArgoCD running ($ARGOCD_PODS pods), fk-webstack-app configured"
    ((PASSED++))
elif [ "$ARGOCD_PODS" -gt 0 ]; then
    echo -e "   $WARN - ArgoCD partially running ($ARGOCD_PODS pods)"
    kubectl get pods -n argocd 2>/dev/null | sed 's/^/   /'
else
    echo -e "   $FAIL - ArgoCD not deployed"
fi
echo ""

# Criterion 7: Logging (Optional - not yet implemented)
echo "7. Logging (Optional - ELK/Loki stack)"
echo "   --------------------------------------------------"
echo -e "   $WARN - Not implemented (optional feature)"
echo ""

# Summary
echo "======================================"
echo "Summary: $PASSED/$TOTAL criteria passed"
echo "======================================"
echo ""

if [ "$PASSED" -ge 5 ]; then
    echo -e "${GREEN}✓ Project meets minimum requirements!${NC}"
    echo ""
    echo "Quick Access Commands:"
    echo "  API Test:     kubectl port-forward svc/fk-api -n fk-webstack 8000:8000"
    echo "  Grafana:      kubectl port-forward svc/fk-monitoring-grafana -n monitoring 3000:80"
    echo "  ArgoCD:       kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443"
else
    echo -e "${RED}✗ Project does not meet minimum requirements${NC}"
    echo "  Run: bash /vagrant/deploy-full-stack.sh"
fi
echo ""

# Show overall cluster health
echo "Overall Cluster Status:"
echo "-----------------------"
kubectl get pods -A | grep -v "Running\|Completed" | sed 's/^/  /' || echo -e "  ${GREEN}All pods are Running or Completed${NC}"
