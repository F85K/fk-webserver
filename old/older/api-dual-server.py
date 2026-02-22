#!/usr/bin/env python3
"""
Dual HTTP/HTTPS API Server with MongoDB Integration
Serves frontend HTML + API endpoints with automatic HTTP→HTTPS redirect
"""

import http.server
import ssl
import json
import os
import threading
from pathlib import Path
from pymongo import MongoClient
from pymongo.errors import ServerSelectionTimeoutError

MONGO_URL = os.getenv('MONGO_URL', 'mongodb://127.0.0.1:27017')
MONGO_DB = os.getenv('MONGO_DB', 'fkdb')
MONGO_COLLECTION = os.getenv('MONGO_COLLECTION', 'profile')
FRONTEND_DIR = '/vagrant/frontend'
CERT_FILE = '/vagrant/server.crt'
KEY_FILE = '/vagrant/server.key'

# MongoDB connection (lazy - will connect on first request)
mongo_client = None
db_connection = None
collection = None

def get_mongo_connection():
    global mongo_client, db_connection, collection
    try:
        if mongo_client is None:
            mongo_client = MongoClient(MONGO_URL, serverSelectionTimeoutMS=5000)
            mongo_client.server_info()  # Test connection
            db_connection = mongo_client[MONGO_DB]
            collection = db_connection[MONGO_COLLECTION]
        return collection
    except Exception as e:
        print(f"[MongoDB] Connection failed: {e}")
        return None

class APIRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, is_https=False, *args, directory=FRONTEND_DIR, **kwargs):
        self.is_https = is_https
        super().__init__(*args, directory=directory, **kwargs)

    def do_GET(self):
        """Handle GET requests"""
        # API endpoints
        if self.path == '/api/name':
            self.send_api_response(self.get_name)
        elif self.path == '/api/container-id':
            self.send_api_response(self.get_container_id)
        elif self.path == '/api/id':
            self.send_api_response(self.get_id)
        elif self.path == '/health':
            self.send_api_response(self.get_health)
        else:
            # Serve static frontend files
            super().do_GET()

    def send_api_response(self, callback):
        """Send JSON API response"""
        try:
            data = callback()
            response_json = json.dumps(data)
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Content-Length', len(response_json))
            self.end_headers()
            self.wfile.write(response_json.encode('utf-8'))
        except Exception as e:
            self.send_error(500, str(e))

    def get_name(self):
        """Query MongoDB for user name"""
        try:
            collection = get_mongo_connection()
            if collection:
                doc = collection.find_one({'key': 'name'})
                if doc:
                    return {'name': doc.get('value', 'Unknown User')}
            return {'name': 'Frank Koch (MongoDB Unavailable)'}
        except Exception as e:
            print(f"[API] Error getting name: {e}")
            return {'name': f'Error: {str(e)[:50]}'}

    def get_id(self):
        """Query MongoDB for user ID"""
        try:
            collection = get_mongo_connection()
            if collection:
                doc = collection.find_one({'key': 'id'})
                if doc:
                    return {'id': doc.get('value', 'Unknown')}
            return {'id': 'N/A'}
        except Exception as e:
            return {'id': f'Error: {str(e)[:50]}'}

    def get_container_id(self):
        """Return container hostname"""
        try:
            import socket
            hostname = socket.gethostname()
            return {'container_id': hostname}
        except Exception as e:
            return {'container_id': f'Error: {str(e)}'}

    def get_health(self):
        """Health check endpoint"""
        collection = get_mongo_connection()
        mongo_status = "connected" if collection else "disconnected"
        protocol = "HTTPS" if self.is_https else "HTTP"
        return {
            'status': 'healthy',
            'mongodb': mongo_status,
            'protocol': protocol,
            'certificate': 'self-signed' if self.is_https else 'none'
        }

    def end_headers(self):
        """Add security headers"""
        if self.is_https:
            self.send_header('Strict-Transport-Security', 'max-age=31536000; includeSubDomains')
        super().end_headers()

    def log_message(self, format, *args):
        """Log HTTP requests"""
        protocol = "HTTPS" if self.is_https else "HTTP"
        print(f"[{protocol}] [{self.client_address[0]}] {format % args}")

def run_http_server():
    """Run HTTP server on port 80"""
    handler = lambda *args, **kwargs: APIRequestHandler(False, *args, directory=FRONTEND_DIR, **kwargs)
    server = http.server.HTTPServer(('0.0.0.0', 80), handler)
    print("📡 HTTP Server started on port 80")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()

def run_https_server():
    """Run HTTPS server on port 443"""
    handler = lambda *args, **kwargs: APIRequestHandler(True, *args, directory=FRONTEND_DIR, **kwargs)
    server = http.server.HTTPServer(('0.0.0.0', 443), handler)
    
    # Wrap with SSL/TLS
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    try:
        context.load_cert_chain(CERT_FILE, KEY_FILE)
        server.socket = context.wrap_socket(server.socket, server_side=True)
        print("🔒 HTTPS Server started on port 443")
        server.serve_forever()
    except Exception as e:
        print(f"✗ HTTPS setup failed: {e}")
        server.server_close()

if __name__ == '__main__':
    print("=" * 60)
    print("🚀 Dual HTTP/HTTPS API Server with MongoDB")
    print("=" * 60)
    print(f"📁 Frontend: {FRONTEND_DIR}")
    print(f"🗄️  MongoDB: {MONGO_URL}")
    print(f"📦 Database: {MONGO_DB}/{MONGO_COLLECTION}")
    print(f"🔐 Certificate: {CERT_FILE}")
    print("=" * 60)
    print("✓ Starting servers...\n")

    # Start HTTP server in background thread
    http_thread = threading.Thread(target=run_http_server, daemon=True)
    http_thread.start()

    # Start HTTPS server in main thread
    try:
        run_https_server()
    except KeyboardInterrupt:
        print("\n👋 Server shutting down...")
