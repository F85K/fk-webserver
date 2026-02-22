#!/usr/bin/env python3
import http.server
import socketserver
import json
import os
from urllib.parse import urlparse

class SimpleHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        # Route API requests
        if path.startswith('/api/'):
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            if path == '/api/name':
                self.wfile.write(json.dumps({'name': 'Kubernetes App (Running on Control Plane)'}).encode())
            elif path == '/api/container-id':
                self.wfile.write(json.dumps({'container_id': 'fk-control'}).encode())
            else:
                self.wfile.write(json.dumps({'message': 'API endpoint'}).encode())
                
        # Route /health
        elif path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'healthy'}).encode())
            
        # Route /
        elif path == '/' or path == '':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            try:
                with open('/vagrant/frontend/index.html', 'rb') as f:
                    self.wfile.write(f.read())
            except:
                self.wfile.write(b'<html><body><h1>Frontend Page</h1><p>Welcome to the Kubernetes App</p></body></html>')
        
        else:
            # Try to serve static files from frontend
            try:
                file_path = '/vagrant/frontend' + path
                if os.path.exists(file_path) and os.path.isfile(file_path):
                    self.send_response(200)
                    self.send_header('Content-type', 'text/html' if path.endswith('.html') else 'text/plain')
                    self.end_headers()
                    with open(file_path, 'rb') as f:
                        self.wfile.write(f.read())
                else:
                    super().do_GET()
            except:
                super().do_GET()
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

PORT = 80
Handler = SimpleHandler

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"Server running on port {PORT}")
    print(f"Frontend: http://0.0.0.0:{PORT}")
    print(f"API: http://0.0.0.0:{PORT}/api/name")
    print(f"Accessible at: http://192.168.56.10:{PORT}")
    httpd.serve_forever()
