#!/bin/bash
set -e

echo "Installing Docker on control plane..."

# Update package list
sudo apt-get update

# Install Docker
sudo apt-get install -y --no-install-recommends docker.io 2>&1 | tail -3

# Start Docker
sudo systemctl start docker 2>&1 || true

echo "Docker installed. Building images..."

# Build API image
echo "1. Building fk-api:latest..."
cd /vagrant/api
sudo docker build -t fk-api:latest . 2>&1 | tail -10

# Build Frontend image
echo "2. Building fk-frontend:latest..."
cd /vagrant/frontend
sudo docker build -t fk-frontend:latest . 2>&1 | tail -10

# Save images as tar
echo "3. Exporting images..."
mkdir -p /tmp/images
sudo docker save fk-api:latest -o /tmp/images/fk-api.tar
sudo docker save fk-frontend:latest -o /tmp/images/fk-frontend.tar

echo "4. Loading into containerd on control plane..."
sudo ctr image import /tmp/images/fk-api.tar
sudo ctr image import /tmp/images/fk-frontend.tar

echo ""
echo "5. Distributing images to workers..."

# Use vagrant scp to copy files
echo "   Copying to fk-worker1..."
vagrant scp /tmp/images/fk-api.tar fk-worker1:/tmp/ 2>&1 | grep -i 'error\|done' || true
vagrant scp /tmp/images/fk-frontend.tar fk-worker1:/tmp/ 2>&1 | grep -i 'error\|done' || true

echo "   Copying to fk-worker2..."
vagrant scp /tmp/images/fk-api.tar fk-worker2:/tmp/ 2>&1 | grep -i 'error\|done' || true
vagrant scp /tmp/images/fk-frontend.tar fk-worker2:/tmp/ 2>&1 | grep -i 'error\|done' || true

echo ""
echo "6. Loading on workers..."
vagrant ssh fk-worker1 -- "sudo ctr image import /tmp/fk-api.tar && echo 'API loaded'" 2>&1 | tail -1
vagrant ssh fk-worker1 -- "sudo ctr image import /tmp/fk-frontend.tar && echo 'Frontend loaded'" 2>&1 | tail -1
vagrant ssh fk-worker2 -- "sudo ctr image import /tmp/fk-api.tar && echo 'API loaded'" 2>&1 | tail -1
vagrant ssh fk-worker2 -- "sudo ctr image import /tmp/fk-frontend.tar && echo 'Frontend loaded'" 2>&1 | tail -1

echo ""
echo "7. Verifying images are available..."
sudo kubectl get pods -n fk-webstack --no-headers | head -3
echo ""
echo "Done! Pods should auto-restart now..."
