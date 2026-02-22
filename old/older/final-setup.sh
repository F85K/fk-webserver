#!/bin/bash
set -e

echo "=== Setting up MongoDB + Frontend ==="

# Initialize MongoDB on localhost
echo "1. Initializing MongoDB data..."
python3 << 'EOEND'
import pymongo
import time

for i in range(10):
    try:
        client = pymongo.MongoClient('mongodb://127.0.0.1:27017', serverSelectionTimeoutMS=2000)
        client.admin.command('ping')
        print("✓ MongoDB connected")
        break
    except:
        if i < 9:
            print(f"  Attempt {i+1}/10...", end=" ")
            time.sleep(1)

db = client['fkdb']
coll = db['profile']
coll.delete_many({"key": "name"})
coll.insert_one({"key": "name", "value": "Frank Koch - Kubernetes Cluster"})
print(f"✓ Data inserted")
EOEND

# Kill old servers
echo "2. Restarting servers..."
sudo killall -9 python3 2>/dev/null || true
sleep 2

# Start frontend/API server
echo "3. Starting API server..."
nohup sudo python3 /vagrant/api-mongodb-server.py > /tmp/api.log 2>&1 &
sleep 3

echo "4. Testing..."
curl -s http://localhost/api/name && echo ""

echo ""
echo "✓ Your frontend now connects to MongoDB!"
echo "Frontend: http://192.168.56.10"
