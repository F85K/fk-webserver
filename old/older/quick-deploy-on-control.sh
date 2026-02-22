#!/bin/bash
set -e

echo "=== Quick deployment on control plane ==="

# First, ensure docker is installed
echo "1. Installing Docker..."
sudo apt-get update -qq && sudo apt-get install -y --no-install-recommends docker.io >/dev/null 2>&1
sudo systemctl enable docker 2>/dev/null || true
sudo systemctl start docker 2>/dev/null || true

# Wait for docker to be ready  
sleep 3

# Build images
echo "2. Building fk-api..."
cd /vagrant/api && sudo docker build -q -t fk-api:latest . 2>&1 | tail -2

echo "3. Building fk-frontend..."
cd /vagrant/frontend && sudo docker build -q -t fk-frontend:latest . 2>&1 | tail -2

# Save to containerd format
echo "4. Converting images to containerd format..."
mkdir -p /tmp/img
sudo docker save fk-api:latest | sudo ctr image import - 2>&1 | grep -i 'imported\|error' || echo "API image converted"
sudo docker save fk-frontend:latest | sudo ctr image import - 2>&1 | grep -i 'imported\|error' || echo "Frontend image converted"

echo ""
echo "5. Updating deployments to run on control plane..."

# Delete old problematic deployments
sudo kubectl delete deployment fk-api fk-frontend -n fk-webstack --ignore-not-found=true

# Create new deployments with nodeSelector for control-plane
cat <<'APIDEPLOY' | sudo kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fk-api
  namespace: fk-webstack
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fk-api
  template:
    metadata:
      labels:
        app: fk-api
    spec:
      nodeSelector:
        kubernetes.io/hostname: fk-control
      hostNetwork: true
      containers:
        - name: fk-api
          image: fk-api:latest
          imagePullPolicy: Never
          ports:
            - containerPort: 8000
          env:
            - name: MONGO_URL
              value: "mongodb://127.0.0.1:27017/fk_database"
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
APIDEPLOY

cat <<'FRONTDEPLOY' | sudo kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fk-frontend
  namespace: fk-webstack
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fk-frontend
  template:
    metadata:
      labels:
        app: fk-frontend
    spec:
      nodeSelector:
        kubernetes.io/hostname: fk-control
      hostNetwork: true
      containers:
        - name: fk-frontend
          image: fk-frontend:latest
          imagePullPolicy: Never
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
FRONTDEPLOY

echo ""
echo "6. Restarting services..."
sudo kubectl rollout restart deployment/fk-mongodb -n fk-webstack 2>/dev/null || true

echo ""
echo "7. Waiting for pods (20s)..."
sleep 20

echo ""
echo "=== Pod Status ===:"
sudo kubectl get pods -n fk-webstack --no-headers | head -10

echo ""
echo "=== Services ===:"
sudo kubectl get svc -n fk-webstack

echo ""
echo "Frontend available at: http://192.168.56.10"
echo "API available at: http://192.168.56.10:8000"
