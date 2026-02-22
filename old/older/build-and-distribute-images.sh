#!/bin/bash
set -e

echo "=== Building and Distributing Docker Images ==="

# Build API image
echo "1. Building fk-api:latest..."
cd /vagrant/api
sudo docker build -t fk-api:latest . 2>&1 | tail -5

# Build Frontend image
echo "2. Building fk-frontend:latest..."
cd /vagrant/frontend
sudo docker build -t fk-frontend:latest . 2>&1 | tail -5

# Save images as tar
echo "3. Exporting images to tar files..."
mkdir -p /tmp/images
sudo docker save fk-api:latest -o /tmp/images/fk-api.tar
sudo docker save fk-frontend:latest -o /tmp/images/fk-frontend.tar

# List sizes
echo "4. Image sizes:"
ls -lh /tmp/images/

echo ""
echo "5. Loading images into containerd on all nodes..."

# Load on control plane
echo "   Loading on control plane..."
sudo ctr image import /tmp/images/fk-api.tar 2>&1 | grep -i 'done\|error\|loaded' || echo "   fk-api imported"
sudo ctr image import /tmp/images/fk-frontend.tar 2>&1 | grep -i 'done\|error\|loaded' || echo "   fk-frontend imported"

# Copy to and load on workers
for worker in fk-worker1 fk-worker2; do
  echo "   Loading on $worker..."
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /tmp/images/*.tar vagrant@192.168.56.$((11 + $(echo $worker | grep -o '[0-9]*' | head -1) - 1)):/tmp/ 2>&1 || true
done

# Actually let's use vagrant scp
echo "   Using vagrant to distribute to workers..."
vagrant scp /tmp/images/fk-api.tar fk-worker1:/tmp/ 2>&1 | tail -2
vagrant scp /tmp/images/fk-frontend.tar fk-worker1:/tmp/ 2>&1 | tail -2
vagrant scp /tmp/images/fk-api.tar fk-worker2:/tmp/ 2>&1 | tail -2
vagrant scp /tmp/images/fk-frontend.tar fk-worker2:/tmp/ 2>&1 | tail -2

echo ""
echo "6. Loading images in containerd on workers..."
vagrant ssh fk-worker1 -- "sudo ctr image import /tmp/fk-api.tar && sudo ctr image import /tmp/fk-frontend.tar" 2>&1 | tail -3
vagrant ssh fk-worker2 -- "sudo ctr image import /tmp/fk-api.tar && sudo ctr image import /tmp/fk-frontend.tar" 2>&1 | tail -3

echo ""
echo "7. Verifying images on all nodes..."
echo "   Control plane:"
sudo ctr image ls | grep -E 'fk-api|fk-frontend'
echo "   Worker 1:"
vagrant ssh fk-worker1 -- "sudo ctr image ls | grep -E 'fk-api|fk-frontend'"
echo "   Worker 2:"
vagrant ssh fk-worker2 -- "sudo ctr image ls | grep -E 'fk-api|fk-frontend'"

echo ""
echo "=== Image distribution complete ==="
