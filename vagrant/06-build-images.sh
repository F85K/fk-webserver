#!/bin/bash
set -e

echo "=== [IMAGES] Building FK Docker images on all nodes ==="

# Build on control plane
echo "Building on fk-control..."
docker build -t fk-api:latest /vagrant/api
docker build -t fk-frontend:latest /vagrant/frontend

# Save images
docker save fk-api:latest -o /tmp/fk-api.tar
docker save fk-frontend:latest -o /tmp/fk-frontend.tar

# Import into containerd (for Kubernetes)
sudo ctr -n k8s.io images import /tmp/fk-api.tar
sudo ctr -n k8s.io images import /tmp/fk-frontend.tar

echo ""
echo "✓ Images built and loaded on fk-control"
echo ""
echo "Verifying images:"
sudo crictl images | grep -E "fk-|REPOSITORY"
