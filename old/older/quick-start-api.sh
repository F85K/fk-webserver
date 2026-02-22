#!/bin/bash
# Quick fix - start API server that connects to MongoDB K8s service

# Kill any existing Python servers
sudo killall -9 python3 2>/dev/null || true
sleep 2

# Start the API server with correct MongoDB K8s service URL
export MONGO_URL="mongodb://fk-mongodb:27017"
export PYTHONUNBUFFERED=1

echo "Starting MongoDB-connected API server..."
nohup sudo python3 /vagrant/api-mongodb-server.py > /tmp/api.log 2>&1 &

sleep 5

# Check if running
if curl -s http://localhost/api/name > /dev/null 2>&1; then
    echo "✓ API server started successfully"
    echo ""
    echo "Frontend: http://192.168.56.10"
    echo "Now pulling real name from MongoDB!"
    curl -s http://localhost/api/name && echo ""
else
    echo "Checking logs..."
    tail /tmp/api.log
fi
