#!/usr/bin/env python3
import pymongo
import sys
import time

print("Waiting for MongoDB at fk-mongodb:27017...")

for attempt in range(20):
    try:
        client = pymongo.MongoClient('mongodb://fk-mongodb:27017', serverSelectionTimeoutMS=3000)
        client.admin.command('ping')
        print("✓ MongoDB connected!")
        break
    except Exception as e:
        if attempt < 19:
            print(f"  Attempt {attempt + 1}/20... ", end="", flush=True)
            time.sleep(2)
        else:
            print(f"\n✗ Failed: {e}")
            sys.exit(1)

# Initialize data
db = client['fkdb']
coll = db['profile']

# Delete any existing data with this key
coll.delete_many({'key': 'name'})

# Insert test data
coll.insert_one({'key': 'name', 'value': 'Frank Koch - Kubernetes Cluster'})

# Verify
doc = coll.find_one({'key': 'name'})
print(f"✓ Inserted and verified: '{doc['value']}'")

client.close()
