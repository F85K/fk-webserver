#!/bin/bash
# Force cleanup of stuck Terminating pods and resources

set +e  # Don't exit on errors

echo "=== Force Cleanup of Stuck Resources ==="

# Function to force delete stuck pods
force_delete_pods() {
    local namespace=$1
    echo "Checking for stuck pods in namespace: $namespace"
    
    # Get all Terminating pods
    STUCK_PODS=$(kubectl get pods -n "$namespace" --field-selector=status.phase=Terminating -o name 2>/dev/null)
    
    if [ -n "$STUCK_PODS" ]; then
        echo "Found stuck Terminating pods in $namespace:"
        echo "$STUCK_PODS"
        
        for pod in $STUCK_PODS; do
            echo "  Force deleting: $pod"
            kubectl delete "$pod" -n "$namespace" --grace-period=0 --force 2>/dev/null || true
        done
    else
        echo "  No stuck pods in $namespace"
    fi
}

# Function to force delete stuck namespaces
force_delete_namespace() {
    local namespace=$1
    
    # Check if namespace is stuck Terminating
    STATUS=$(kubectl get namespace "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
    
    if [ "$STATUS" == "Terminating" ]; then
        echo "Namespace $namespace is stuck in Terminating state"
        echo "Attempting to remove finalizers..."
        
        kubectl get namespace "$namespace" -o json | \
            jq '.spec.finalizers = []' | \
            kubectl replace --raw "/api/v1/namespaces/$namespace/finalize" -f - || true
    fi
}

# Clean up common namespaces
NAMESPACES="fk-webstack cert-manager monitoring argocd"

for ns in $NAMESPACES; do
    if kubectl get namespace "$ns" &>/dev/null; then
        force_delete_pods "$ns"
        force_delete_namespace "$ns"
    fi
done

# Also check kube-system for stuck resources
force_delete_pods "kube-system"

# Clean up failed init jobs
echo "Cleaning up completed/failed jobs..."
kubectl delete jobs -n fk-webstack --field-selector status.successful=1 2>/dev/null || true
kubectl delete jobs -n fk-webstack --field-selector status.failed=1 2>/dev/null || true

# Restart kubelet on all nodes to clear any cached state
echo "You may need to restart kubelet on all nodes:"
echo "  vagrant ssh fk-control -c 'sudo systemctl restart kubelet'"
echo "  vagrant ssh fk-worker1 -c 'sudo systemctl restart kubelet'"
echo "  vagrant ssh fk-worker2 -c 'sudo systemctl restart kubelet'"

echo "✓ Cleanup complete"
