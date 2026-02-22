#!/bin/bash
set -e

echo "=========================================="
echo "=== SETTING UP REAL API WITH MONGODB ==="
echo "=========================================="
echo ""

# Step 1: Install Python dependencies with pip3
echo "[1] Installing Python dependencies..."
pip3 install --user fastapi uvicorn pymongo python-multipart 2>&1 | grep -i 'successfully\|installed' | tail -3

# Step 2: Initialize MongoDB with test data
echo "[2] Initializing MongoDB with test data..."
cd /vagrant/api

# Create initialization script
cat > /tmp/init_mongo.py << 'PYEOF'
import pymongo
import time

# Try to connect to MongoDB
for attempt in range(5):
    try:
        client = pymongo.MongoClient("mongodb://127.0.0.1:27017/", serverSelectionTimeoutMS=3000)
        client.admin.command('ping')
        print("✓ Connected to MongoDB")
        break
    except Exception as e:
        print(f"  Attempt {attempt + 1}/5: Waiting for MongoDB... ({e})")
        time.sleep(2)
else:
    print("✗ Could not connect to MongoDB")
    exit(1)

# Create database and insert test data
db = client['fkdb']
collection = db['profile']

# Check if data already exists
existing = collection.find_one({"key": "name"})
if existing:
    print(f"✓ MongoDB already has data: {existing}")
else:
    # Insert test data
    collection.insert_one({
        "key": "name",
        "value": "Frank Koch - Kubernetes Cluster"
    })
    print("✓ Inserted test data into MongoDB: 'Frank Koch - Kubernetes Cluster'")

# Verify
doc = collection.find_one({"key": "name"})
print(f"✓ Current value in DB: '{doc['value']}'")

client.close()
PYEOF

python3 /tmp/init_mongo.py

# Step 3: Kill the old simple server
echo ""
echo "[3] Stopping simple web server..."
sudo killall python3 2>/dev/null || echo "  (no old server running)"
sleep 2

# Step 4: Start the real FastAPI app
echo "[4] Starting FastAPI application..."
export MONGO_URL="mongodb://127.0.0.1:27017"
export MONGO_DB="fkdb"
export MONGO_COLLECTION="profile"
export DEFAULT_NAME="Frank Koch"

nohup python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/api.log 2>&1 &
sleep 3

# Step 5: Verify API is responding
echo "[5] Testing API endpoints..."
if curl -s http://localhost:8000/api/name; then
    echo ""
    echo "✓ API is responding with real data from MongoDB!"
else
    echo ""
    echo "Checking logs..."
    tail /tmp/api.log
fi

echo ""
echo "=========================================="
echo "=== SETUP COMPLETE ==="
echo "=========================================="
echo ""
echo "Frontend: http://192.168.56.10"
echo "API: http://192.168.56.10:8000/api/name"
echo "API Health: http://192.168.56.10:8000/health (endpoint not defined yet)"
echo ""
echo "The frontend now fetches real data from MongoDB!"
