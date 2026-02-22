#!/bin/bash
set -e

echo "=========================================="
echo "=== PRAGMATIC DEPLOYMENT (Direct Python) ==="
echo "=========================================="
echo ""

# Step 1: Verify MongoDB is running
echo "[1] Checking MongoDB..."
if sudo kubectl get pods -n fk-webstack | grep -q "fk-mongodb.*1/1.*Running"; then
    echo "  ✓ MongoDB running"
elif sudo kubectl get pods -n fk-webstack | grep -q "mongo.*Running"; then
    echo "  ✓ MongoDB running  (on worker)"
else
    echo "  ✗ MongoDB not running, deploying..."
    sudo kubectl apply -f /vagrant/app-stack-control-plane.yaml
    sleep 5
fi

# Step 2: Install Python dependencies on control plane
echo "[2] Installing Python dependencies..."
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends python3-pip python3-fastapi python3 python3-uvicorn >/dev/null 2>&1
pip3 install -q pymongo python-multipart 2>/dev/null || true

echo " Dependencies installed"

# Step 3: Start API server in background
echo "[3] Starting FastAPI server..."
cd /vagrant/api
nohup python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/api.log 2>&1 &
sleep 3

if curl -s http://localhost:8000/health >/dev/null; then
    echo "  ✓ API running on port 8000"
else
    echo "  ✗ API startup issue, check /tmp/api.log"
fi

# Step 4: Start Frontend server
echo "[4] Starting Frontend server..."
cd /vagrant/frontend
python3 -m http.server 80 > /tmp/frontend.log 2>&1 &
sleep 2

if curl -s http://localhost:80 | grep -q 'html\|html'; then
    echo "  ✓ Frontend running on port 80"
else
    echo "  (Frontend may need adjustment)"
fi

echo ""
echo "=========================================="
echo "=== SERVICES READY ==="
echo "=========================================="
echo ""
echo "Frontend: http://192.168.56.10"
echo "API: http://192.168.56.10:8000"
echo ""
echo "Test API health:"
curl -s -I http://localhost:8000/health | head -1
echo ""
echo "=========================================="
