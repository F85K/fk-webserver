#!/bin/bash
set -e

echo "=== Deploying Full Stack with hostNetwork: true ==="
echo ""

# Create namespace if missing
echo "1. Ensuring fk-webstack namespace..."
sudo kubectl create namespace fk-webstack --dry-run=client -o yaml | sudo kubectl apply -f -

# Apply MongoDB with hostNetwork
echo "2. Deploying MongoDB with hostNetwork..."
cat <<'MONGOYAML' | sudo kubectl apply -f -
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
      hostNetwork: true
      containers:
        - name: fk-mongodb
          image: mongo:6.0
          ports:
            - containerPort: 27017
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          volumeMounts:
            - name: mongo-data
              mountPath: /data/db
      volumes:
        - name: mongo-data
          emptyDir: {}
MONGOYAML

# MongoDB Service for internal K8s DNS
echo "3. Creating MongoDB service..."
cat <<'MONGOSVC' | sudo kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: fk-mongodb
  namespace: fk-webstack
spec:
  selector:
    app: fk-mongodb
  ports:
    - port: 27017
      targetPort: 27017
  type: ClusterIP
MONGOSVC

# Wait for MongoDB to be ready
echo "4. Waiting for MongoDB pod to be ready (max 30s)..."
sleep 2
sudo kubectl rollout status deployment/fk-mongodb -n fk-webstack --timeout=30s 2>/dev/null || echo "   (still initializing...)"

# Apply API Deployment with hostNetwork
echo "5. Deploying API with hostNetwork..."
cat <<'APIYAML' | sudo kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fk-api
  namespace: fk-webstack
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fk-api
  template:
    metadata:
      labels:
        app: fk-api
    spec:
      hostNetwork: true
      containers:
        - name: fk-api
          image: fk-api:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8000
          env:
            - name: MONGO_URL
              value: "mongodb://localhost:27017/fk_database"
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
APIYAML

# API Service
echo "6. Creating API service..."
cat <<'APISVC' | sudo kubectl apply -f -
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
  type: NodePort
APISVC

# Apply Frontend Deployment with hostNetwork
echo "7. Deploying Frontend with hostNetwork..."
cat <<'FRONTYAML' | sudo kubectl apply -f -
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
      hostNetwork: true
      containers:
        - name: fk-frontend
          image: fk-frontend:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
FRONTYAML

# Frontend Service
echo "8. Creating Frontend service..."
cat <<'FRONTSVC' | sudo kubectl apply -f -
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
  type: NodePort
FRONTSVC

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Waiting for pods to start (20s)..."
sleep 20
echo ""
echo "Pod Status:"
sudo kubectl get pods -n fk-webstack --no-headers || echo "Pods still initializing..."
echo ""
echo "Services:"
sudo kubectl get svc -n fk-webstack
echo ""
echo "Next steps:"
echo "  Monitor: kubectl get pods -n fk-webstack -w"
echo "  API endpoint: http://192.168.56.10:8000 or http://192.168.56.11:8000 or http://192.168.56.12:8000"
echo "  Frontend: http://192.168.56.10:80 or any worker IP:80"
