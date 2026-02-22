#!/bin/bash
set -e

echo "Installing nerdctl (Docker CLI for containerd)..."

# Download and install nerdctl
cd /tmp
NERDCTL_VERSION="1.9.0"
wget -q https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-amd64.tar.gz
tar -xzf nerdctl-${NERDCTL_VERSION}-linux-amd64.tar.gz
sudo mv nerdctl /usr/local/bin/
sudo chmod +x /usr/local/bin/nerdctl

echo "nerdctl installed. Building images..."
echo ""

# Build images using nerdctl
echo "Building fk-api..."
cd /vagrant/api
sudo /usr/local/bin/nerdctl build -q -t fk-api:latest . 2>&1 | tail -3
sleep 2

echo "Building fk-frontend..."
cd /vagrant/frontend
sudo /usr/local/bin/nerdctl build -q -t fk-frontend:latest . 2>&1 | tail -3
sleep 2

echo ""
echo "Images built. Verifying..."
sudo nerdctl image ls | grep -E 'fk-api|fk-frontend'

echo ""
echo "Applying Kubernetes manifests..."
sleep 2
sudo kubectl apply -f /vagrant/app-stack-control-plane.yaml

echo ""
echo "Waiting 20 seconds for pods to start..."
sleep 20

echo ""
echo "Pod Status:"
sudo kubectl get pods -n fk-webstack --no-headers | head -10

echo ""
echo "Frontend URL: http://192.168.56.10"
echo "API URL: http://192.168.56.10:8000"
