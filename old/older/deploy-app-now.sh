#!/bin/bash
set -e

echo "=========================================="
echo "=== FINAL APP STACK DEPLOYMENT ==="
echo "=========================================="
echo ""

# Step 1: Install Docker if needed
echo "[1/6] Ensuring Docker is available..."
if ! command -v docker &> /dev/null; then
    echo "  Installing Docker..."
    sudo apt-get update -qq
    sudo apt-get install -y --no-install-recommends docker.io >/dev/null 2>&1
    sudo systemctl enable docker 2>/dev/null || true
    sudo systemctl start docker 2>/dev/null || true
    sleep 3
    echo "  Docker installed"
else
    echo "  Docker already available"
fi

# Step 2: Ensure docker daemon is running
sudo systemctl is-active docker >/dev/null || sudo systemctl start docker
sleep 2

# Step 3: Build API image
echo "[2/6] Building fk-api image..."
cd /vagrant/api
sudo docker build -q -t fk-api:latest . 2>&1 | grep -i 'built\|error' || echo "  Build in progress..."
sleep 2

# Step 4: Build Frontend image
echo "[3/6] Building fk-frontend image..."
cd /vagrant/frontend
sudo docker build -q -t fk-frontend:latest . 2>&1 | grep -i 'built\|error' || echo "  Build in progress..."
sleep 2

# Step 5: Load into containerd
echo "[4/6] Loading images into containerd..."
sudo docker save fk-api:latest 2>/dev/null | sudo ctr image import - 2>&1 | grep -i imported || echo "  fk-api ready"
sudo docker save fk-frontend:latest 2>/dev/null | sudo ctr image import - 2>&1 | grep -i imported || echo "  fk-frontend ready"

# Step 6: Verify images
echo "[5/6] Verifying images..."
sudo ctr image ls | grep -E 'fk-api|fk-frontend' | wc -l | xargs echo "  Images available:"

# Step 7: Apply manifests
echo "[6/6] Deploying application stack..."
sudo kubectl apply -f /vagrant/app-stack-control-plane.yaml

echo ""
echo "=========================================="
echo "=== WAITING FOR PODS TO START ==="
echo "=========================================="
echo ""

sleep 10

# Monitor pod startup
for i in {1..30}; do
    echo -n "."
    sleep 1
    if sudo kubectl get pods -n fk-webstack --no-headers 2>/dev/null | grep -q "1/1.*Running"; then
        sleep 3
        break
    fi
done

echo ""
echo ""
echo "=========================================="
echo "=== DEPLOYMENT STATUS ==="
echo "=========================================="
echo ""

echo "Pod Status:"
sudo kubectl get pods -n fk-webstack --no-headers

echo ""
echo "Services:"
sudo kubectl get svc -n fk-webstack --no-headers

echo ""
echo "=========================================="
echo "=== ACCESS INFORMATION ==="
echo "=========================================="
echo ""
echo "Frontend:"
echo "  URL: http://192.168.56.10"
echo ""
echo "API:"
echo "  URL: http://192.168.56.10:8000"
echo "  Health: http://192.168.56.10:8000/health"
echo ""
echo "MongoDB:"
echo "  Host: 127.0.0.1:27017 (on control plane)"
echo ""
echo "=========================================="
