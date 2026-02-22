#!/bin/bash
set -e

echo "=========================================="
echo "=== MONGODB + REAL API SETUP ==="
echo "=========================================="
echo ""

# Step 1: Install pymongo
echo "[1] Installing pymongo..."
python3 -m pip install --quiet pymongo 2>/dev/null || python3 -c "import pymongo" || {
    echo "  Installing via apt..."
    sudo apt-get install -y python3-pymongo 2>&1 | tail -2
}

# Step 2: Initialize MongoDB with test data
echo "[2] Initializing MongoDB..."
python3 << 'PYEOF'
import pymongo
import time
import sys

for attempt in range(10):
    try:
        client = pymongo.MongoClient("mongodb://127.0.0.1:27017/", serverSelectionTimeoutMS=3000)
        client.admin.command('ping')
        print("  ✓ Connected to MongoDB")
        break
    except Exception as e:
        if attempt < 9:
            print(f"  Attempt {attempt + 1}/10: Waiting... ", end="", flush=True)
            time.sleep(2)
        else:
            print(f"\n✗ Failed to connect: {e}")
            sys.exit(1)

db = client['fkdb']
coll = db['profile']

# Check and insert data
existing = coll.find_one({"key": "name"})
if existing:
    print(f"  ✓ MongoDB already has: '{existing['value']}'")
else:
    coll.insert_one({"key": "name", "value": "Frank Koch - Kubernetes Cluster"})
    print("  ✓ Inserted: 'Frank Koch - Kubernetes Cluster'")

doc = coll.find_one({"key": "name"})
print(f"  ✓ Verified: '{doc['value']}'")
client.close()
PYEOF

# Step 3: Kill old servers
echo "[3] Stopping old servers..."
sudo killall python3 2>/dev/null || true
sleep 2

# Step 4: Start real API server with MongoDB
echo "[4] Starting MongoDB-connected API server..."
cd /vagrant
export MONGO_URL="mongodb://127.0.0.1:27017"
export MONGO_DB="fkdb"
export MONGO_COLLECTION="profile"

nohup sudo python3 api-mongodb-server.py > /tmp/api-mongodb.log 2>&1 &
sleep 3

# Step 5: Verify
echo "[5] Testing API..."
if curl -s http://localhost/api/name | grep -q "Frank Koch"; then
    echo "  ✓ API working with real MongoDB data!"
    curl -s http://localhost/api/name
else
    echo "  Checking logs..."
    tail -10 /tmp/api-mongodb.log
fi

echo ""
echo "=========================================="
echo "=== SETUP COMPLETE ==="
echo "=========================================="
echo ""
echo "Frontend: http://192.168.56.10"
echo "  → Displays name fetched from MongoDB"
echo ""
echo "API: http://192.168.56.10/api/name"
echo "  → Returns real data from MongoDB"
echo ""
echo "Your frontend now pulls real data from MongoDB!"
