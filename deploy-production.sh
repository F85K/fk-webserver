#!/bin/bash
set -e

echo "======================================"
echo "Production Deployment - Optimized"
echo "======================================"
echo ""

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=$3
    echo "Waiting for $deployment to be ready (max ${timeout}s)..."
    kubectl rollout status deployment/$deployment -n $namespace --timeout=${timeout}s 2>/dev/null || true
}

# Step 1: Create namespace
echo "Step 1: Creating namespace..."
kubectl create namespace fk-webstack 2>/dev/null || echo "Namespace already exists"

# Step 2: Deploy MongoDB with optimized resources
echo ""
echo "Step 2: Deploying MongoDB..."
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: fk-mongodb
  namespace: fk-webstack
spec:
  clusterIP: None
  selector:
    app: fk-mongodb
  ports:
    - port: 27017
      targetPort: 27017
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fk-mongodb
  namespace: fk-webstack
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fk-mongodb
  template:
    metadata:
      labels:
        app: fk-mongodb
    spec:
      containers:
        - name: mongodb
          image: mongo:6
          ports:
            - containerPort: 27017
          resources:
            requests:
              cpu: "100m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          livenessProbe:
            exec:
              command:
                - mongosh
                - --eval
                - "db.adminCommand('ping')"
            initialDelaySeconds: 30
            periodSeconds: 10
EOF

echo "Waiting for MongoDB..."
sleep 15
wait_for_deployment fk-webstack fk-mongodb 120

# Step 3: Deploy API
echo ""
echo "Step 3: Deploying API..."
cat <<'EOF' | kubectl apply -f -
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
      containers:
        - name: fk-api
          image: fk-api:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8000
          env:
            - name: MONGO_URL
              value: mongodb://fk-mongodb:27017
            - name: MONGO_DB
              value: fkdb
            - name: MONGO_COLLECTION
              value: profile
            - name: NAME_KEY
              value: name
            - name: DEFAULT_NAME
              value: Frank Koch
          resources:
            requests:
              cpu: "50m"
              memory: "128Mi"
            limits:
              cpu: "250m"
              memory: "256Mi"
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 15
            periodSeconds: 10
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 10
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: fk-api
  namespace: fk-webstack
spec:
  selector:
    app: fk-api
  ports:
    - port: 8000
      targetPort: 8000
  type: ClusterIP
EOF

echo "Waiting for API..."
sleep 10
wait_for_deployment fk-webstack fk-api 120

# Step 4: Deploy Frontend
echo ""
echo "Step 4: Deploying Frontend..."
cat <<'EOF' | kubectl apply -f -
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
      containers:
        - name: fk-frontend
          image: fk-frontend:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "25m"
              memory: "64Mi"
            limits:
              cpu: "100m"
              memory: "128Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: fk-frontend
  namespace: fk-webstack
spec:
  selector:
    app: fk-frontend
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
EOF

echo "Waiting for Frontend..."
sleep 10
wait_for_deployment fk-webstack fk-frontend 120

# Step 5: Summary
echo ""
echo "======================================"
echo "✅ DEPLOYMENT COMPLETE"
echo "======================================"
echo ""
echo "Cluster Status:"
kubectl get nodes
echo ""
echo "Application Status:"
kubectl get all -n fk-webstack
echo ""
echo "Services:"
echo "  API:      kubectl port-forward -n fk-webstack svc/fk-api 8000:8000"
echo "  Frontend: kubectl port-forward -n fk-webstack svc/fk-frontend 3000:80"
echo ""
