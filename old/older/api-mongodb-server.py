#!/usr/bin/env python3
"""
MongoDB-Connected API Server
Serves both frontend and API with real MongoDB data
"""
import http.server
import socketserver
import json
import os
import sys
from urllib.parse import urlparse
from pymongo import MongoClient
from pymongo.errors import ConnectionFailure, ServerSelectionTimeoutError

# MongoDB configuration - use locahost for hostnet MongoDB pod
MONGO_URL = os.getenv('MONGO_URL', 'mongodb://127.0.0.1:27017')
MONGO_DB = os.getenv('MONGO_DB', 'fkdb')
MONGO_COLLECTION = os.getenv('MONGO_COLLECTION', 'profile')

# MongoDB client (lazy loaded)
mongo_client = None
mongo_collection = None

def get_mongo_collection():
    """Get MongoDB collection with lazy initialization"""
    global mongo_client, mongo_collection
    
    if mongo_collection is not None:
        return mongo_collection
    
    try:
        print(f"Connecting to MongoDB at {MONGO_URL}...")
        mongo_client = MongoClient(MONGO_URL, serverSelectionTimeoutMS=5000)
        mongo_client.admin.command('ping')
        mongo_collection = mongo_client[MONGO_DB][MONGO_COLLECTION]
        print("✓ MongoDB connected successfully")
        return mongo_collection
    except (ConnectionFailure, ServerSelectionTimeoutError) as e:
        print(f"✗ MongoDB connection failed: {e}")
        return None

def get_name_from_db():
    """Get name from MongoDB or return default"""
    try:
        coll = get_mongo_collection()
        if coll is None:
            print("MongoDB unavailable, using default name")
            return "Frank Koch (MongoDB Unavailable)"
        
        doc = coll.find_one({"key": "name"})
        if doc and "value" in doc:
            return str(doc["value"])
        else:
            print("No 'name' document found in MongoDB, using default")
            return "Frank Koch (No Data Found)"
    except Exception as e:
        print(f"Error reading from MongoDB: {e}")
        return f"Frank Koch (Error: {str(e)})"

class APIHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        print(f"[{self.client_address[0]}] GET {path}")
        
        # API Endpoints
        if path == '/api/name':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            name = get_name_from_db()
            response = {"name": name}
            self.wfile.write(json.dumps(response).encode())
            
        elif path == '/api/container-id':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            import socket
            container_id = socket.gethostname()
            response = {"container_id": container_id}
            self.wfile.write(json.dumps(response).encode())
            
        elif path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "healthy"}).encode())
            
        elif path == '/' or path == '':
            # Serve frontend HTML
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            try:
                with open('/vagrant/frontend/index.html', 'rb') as f:
                    self.wfile.write(f.read())
            except:
                self.wfile.write(b'<html><body><h1>Frontend</h1></body></html>')
        
        else:
            # Try static files
            try:
                file_path = '/vagrant/frontend' + path
                if os.path.exists(file_path) and os.path.isfile(file_path):
                    self.send_response(200)
                    if path.endswith('.html'):
                        self.send_header('Content-type', 'text/html')
                    elif path.endswith('.css'):
                        self.send_header('Content-type', 'text/css')
                    elif path.endswith('.js'):
                        self.send_header('Content-type', 'application/javascript')
                    self.end_headers()
                    with open(file_path, 'rb') as f:
                        self.wfile.write(f.read())
                else:
                    self.send_response(404)
                    self.end_headers()
            except:
                self.send_response(404)
                self.end_headers()
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def log_message(self, format, *args):
        # Suppress default logging
        pass

if __name__ == '__main__':
    PORT = 80
    
    # Pre-connect to MongoDB
    print("=" * 50)
    print("MongoDB-Connected API Server")
    print("=" * 50)
    get_mongo_collection()
    
    Handler = APIHandler
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"\n✓ Server running on port {PORT}")
        print(f"Frontend: http://192.168.56.10")
        print(f"API: http://192.168.56.10/api/name")
        print("\nCTRL+C to stop\n")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down...")
            sys.exit(0)
