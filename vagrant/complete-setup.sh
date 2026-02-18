#!/bin/bash
# Complete the cluster setup after partial vagrant up

set +e  # Don't exit on errors

echo "======================================"
echo "Completing FK Webstack Cluster Setup"
echo "======================================"
echo ""

# Fix Flannel installation if it failed
echo "Step 1: Ensuring Flannel is installed..."
if ! kubectl get namespace kube-flannel &>/dev/null; then
    echo "  Installing Flannel CNI..."
    kubectl apply -f https://github.com/flannel-io/flannel/releases/download/v0.25.1/kube-flannel.yml
    sleep 10
    
    # Create marker file
    touch /vagrant/kubeadm-config/.flannel-ready
    chmod 666 /vagrant/kubeadm-config/.flannel-ready
else
    echo "  ✓ Flannel already installed"
fi

# Wait for Flannel to be ready
echo "  Waiting for Flannel to be ready..."
sleep 20
kubectl wait --for=condition=Ready pod -l app=flannel -n kube-flannel --timeout=120s 2>/dev/null || {
    echo "  ⚠️  Flannel pods still starting, checking status..."
    kubectl get pods -n kube-flannel
}

echo ""
echo "Step 2: Checking cluster status..."
kubectl get nodes
echo ""
kubectl get pods -A

echo ""
echo "======================================"
echo "Cluster Ready for Workers"
echo "======================================"
echo ""
echo "Flannel marker files:"
ls -la /vagrant/kubeadm-config/
echo ""
echo "Next steps:"
echo "  1. On Windows: vagrant up          (to start workers)"
echo "  2. Wait 5-10 minutes for workers to join"
echo "  3. Run: bash /vagrant/vagrant/deploy-full-stack.sh"
echo "  4. Run: bash /vagrant/vagrant/verify-success-criteria.sh"
