#!/bin/bash
set -e

echo "=== [IMAGES] Loading FK Docker images into containerd ==="

# Check if images exist on host
if [ ! -f "/vagrant/fk-api.tar" ] || [ ! -f "/vagrant/fk-frontend.tar" ]; then
    echo "❌ Error: Docker images not found in /vagrant/"
    echo "Please run on Windows host:"
    echo "  docker save fk-api:latest -o fk-api.tar"
    echo "  docker save fk-frontend:latest -o fk-frontend.tar"
    exit 1
fi

# Import images into containerd
echo "Loading fk-api:latest..."
sudo ctr -n k8s.io images import /vagrant/fk-api.tar

echo "Loading fk-frontend:latest..."
sudo ctr -n k8s.io images import /vagrant/fk-frontend.tar

# Verify images
echo ""
echo "Loaded images:"
sudo crictl images | grep fk-

echo ""
echo "✓ Images loaded successfully"
