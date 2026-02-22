#!/bin/bash

echo "Installing pip3..."
sudo apt-get update -qq && sudo apt-get install -y python3-pip >/dev/null 2>&1

echo "Installing FastAPI dependencies..."
pip3 install -q --user fastapi uvicorn pymongo 2>&1 | tail -3

echo "Starting API..."
cd /vagrant/api
mkdir -p ~/.local/bin
export PATH=$HOME/.local/bin:$PATH
nohup python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/api.log 2>&1 &

echo "Starting Frontend..."
cd /vagrant/frontend
nohup python3 -m http.server 80 > /tmp/frontend.log 2>&1 &

echo "Waiting..."
sleep 3

echo "API health check:"
curl -s http://localhost:8000/health || echo "API not responding yet"

echo ""
echo "=== APPS DEPLOYED ==="
echo "Frontend: http://192.168.56.10"
echo "API: http://192.168.56.10:8000/health"
