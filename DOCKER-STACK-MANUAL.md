# Docker Stack Manual Setup: FK Webstack (Before Kubernetes)

Complete guide on how to manually set up the FK Webstack using Docker Desktop and terminal commands. This documents the baseline setup (10/20 assignment points) before migration to Kubernetes.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Directory Structure](#directory-structure)
3. [Manual Setup (Docker Desktop)](#manual-setup-docker-desktop)
4. [Complete File Contents](#complete-file-contents)
5. [Running the Stack](#running-the-stack)
6. [Verification & Testing](#verification--testing)
7. [Troubleshooting](#troubleshooting)

---

## Project Overview

### Stack Components

| Component | Technology | Purpose | Port |
|-----------|------------|---------|------|
| Frontend | Lighttpd | Serves HTML/CSS/JS | 8080 |
| API | FastAPI (Python) | Provides REST endpoints | 8000 |
| Database | MongoDB | Stores name data | 27017 |

### Architecture Diagram

```
┌──────────────────────────────────────────────────────┐
│         Docker Desktop (Development)                  │
├──────────────────────────────────────────────────────┤
│                                                       │
│  [localhost:8080] ──→ Frontend Container (lighttpd)  │
│                           ↓                          │
│                      index.html                      │
│                           ↓                          │
│                    fetch /api/name                   │
│                           ↓                          │
│  [localhost:8000] ──→ API Container (FastAPI)        │
│                      - GET /api/name                 │
│                      - GET /api/container-id         │
│                      - GET /health                   │
│                           ↓                          │
│  [localhost:27017] ──→ MongoDB Container             │
│                    - Storage: {"name": "..."}        │
│                                                       │
└──────────────────────────────────────────────────────┘
```

### Assignment Requirements (Baseline: 10/20 points)

✅ **3-container web stack:**
- Frontend: Lighttpd serving HTML/JavaScript
- API: FastAPI with REST endpoints
- Database: MongoDB
- API endpoint reads name from database
- API endpoint returns container ID
- Frontend automatically updates when name changes (after refresh)

---

## Directory Structure

### Project Layout

```
fk-webserver/
├── docker-compose.yaml          # Orchestrates all 3 containers
│
├── frontend/
│   ├── Dockerfile               # Builds lighttpd image
│   ├── lighttpd.conf            # Web server configuration
│   └── index.html               # (Given - do not modify)
│
├── api/
│   ├── Dockerfile               # Builds FastAPI image
│   ├── requirements.txt          # Python dependencies
│   └── app/
│       └── main.py              # FastAPI application
│
└── db/
    └── init/
        └── init.js              # MongoDB init script
```

---

## Manual Setup (Docker Desktop)

### Prerequisites

1. **Docker Desktop installed** - https://www.docker.com/products/docker-desktop
2. **Terminal access** - PowerShell or cmd (Windows), Terminal (Mac/Linux)
3. **Project files created** - See "Complete File Contents" below

### Step-by-Step Setup

#### Step 1: Create Project Directory Structure

```powershell
# Create project folder
mkdir fk-webserver
cd fk-webserver

# Create subdirectories
mkdir frontend
mkdir api
mkdir api\app
mkdir db\init
```

#### Step 2: Create MongoDB Init Script

**File:** `db/init/init.js`

```javascript
const dbName = "fkdb";
const collectionName = "profile";
const dbRef = db.getSiblingDB(dbName);

dbRef[collectionName].updateOne(
  { key: "name" },
  { $set: { key: "name", value: "Frank Koch" } },
  { upsert: true }
);
```

#### Step 3: Create API Files

**File:** `api/requirements.txt`

```
fastapi==0.115.6
uvicorn[standard]==0.30.6
pymongo==4.8.0
```

**File:** `api/Dockerfile`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY app /app/app

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**File:** `api/app/main.py`

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pymongo import MongoClient
from pymongo.errors import ServerSelectionTimeoutError, ConnectionFailure
import os
import socket
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

MONGO_URL = os.getenv("MONGO_URL", "mongodb://fk-mongo:27017")
MONGO_DB = os.getenv("MONGO_DB", "fkdb")
MONGO_COLLECTION = os.getenv("MONGO_COLLECTION", "profile")
NAME_KEY = os.getenv("NAME_KEY", "name")
DEFAULT_NAME = os.getenv("DEFAULT_NAME", "Frank Koch")

app = FastAPI(title="FK API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

client = None
collection = None

def get_db_collection():
    """Lazy MongoDB connection"""
    global client, collection
    if client is None:
        logger.info(f"Connecting to MongoDB at {MONGO_URL}")
        client = MongoClient(MONGO_URL, serverSelectionTimeoutMS=5000, connectTimeoutMS=5000)
        try:
            client.admin.command('ping')
            logger.info("✓ MongoDB connected successfully")
        except (ServerSelectionTimeoutError, ConnectionFailure) as e:
            logger.error(f"✗ MongoDB connection failed: {e}")
            client = None
            return None
        collection = client[MONGO_DB][MONGO_COLLECTION]
    return collection

def get_name_from_db() -> str:
    try:
        coll = get_db_collection()
        if coll is None:
            logger.warning("MongoDB unavailable, using default name")
            return DEFAULT_NAME
        doc = coll.find_one({"key": NAME_KEY})
        if doc and "value" in doc:
            return str(doc["value"])
    except Exception as e:
        logger.error(f"Error reading from MongoDB: {e}")
    return DEFAULT_NAME

@app.get("/api/name")
def read_name():
    name = get_name_from_db()
    return {"name": name}

@app.get("/api/container-id")
def read_container_id():
    container_id = socket.gethostname()
    return {"container_id": container_id}

@app.get("/health")
def healthcheck():
    return {"status": "ok"}
```

#### Step 4: Create Frontend Files

**File:** `frontend/lighttpd.conf`

```properties
server.document-root = "/var/www/html"
server.port = 80
server.bind = "0.0.0.0"

index-file.names = ( "index.html" )

server.errorlog = "/proc/self/fd/2"
accesslog.filename = "/proc/self/fd/1"

mimetype.assign = (
  ".html" => "text/html",
  ".js"   => "application/javascript",
  ".css"  => "text/css",
  ".json" => "application/json"
)
```

**File:** `frontend/Dockerfile`

```dockerfile
FROM debian:bookworm-slim

RUN apt-get update \
	&& apt-get install -y --no-install-recommends lighttpd ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/html /var/log/lighttpd

COPY lighttpd.conf /etc/lighttpd/lighttpd.conf

COPY index.html /var/www/html/index.html

EXPOSE 80

CMD ["lighttpd", "-D", "-f", "/etc/lighttpd/lighttpd.conf"]
```

**File:** `frontend/index.html` (GIVEN - provided by assignment)

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Milestone 2</title>
  </head>
  <body>
    <h1><span id="user">Loading...</span> has reached milestone 2!</h1>

    <script>
      const apiUrl = window.location.hostname === "localhost" 
        ? "http://localhost:8000/api/name"
        : "/api/name";
      
      fetch(apiUrl)
        .then((res) => res.json())
        .then((data) => {
          const user = data.name;
          document.getElementById("user").innerText = user;
        });
    </script>
  </body>
</html>
```

#### Step 5: Create Docker Compose File

**File:** `docker-compose.yaml`

```yaml
# Docker Compose for FK Webstack (3-container baseline)
services:
  # MongoDB Database
  fk-mongo:
    image: mongo:6
    container_name: fk-mongo
    ports:
      - "27017:27017"
    volumes:
      # Init script runs on first start
      - ./db/init/init.js:/docker-entrypoint-initdb.d/init.js:ro

  # FastAPI Service
  fk-api:
    build: ./api
    container_name: fk-api
    ports:
      - "8000:8000"
    environment:
      - MONGO_URL=mongodb://fk-mongo:27017
      - MONGO_DB=fkdb
      - MONGO_COLLECTION=profile
      - NAME_KEY=name
      - DEFAULT_NAME=Frank Koch
    depends_on:
      - fk-mongo

  # Lighttpd Frontend
  fk-frontend:
    build: ./frontend
    container_name: fk-frontend
    ports:
      - "8080:80"
    depends_on:
      - fk-api
```

---

## Complete File Contents

### Directory Tree with Descriptions

```
fk-webserver/
│
├── docker-compose.yaml
│   └── Orchestrates MongoDB, API, Frontend containers
│       - Defines services, ports, volumes, dependencies
│       - Builds API and Frontend images
│       - Sets environment variables for API
│       - Mounts MongoDB init script
│
├── frontend/
│   │
│   ├── Dockerfile
│   │   └── Builds lighttpd image
│   │       - Base: debian:bookworm-slim
│   │       - Installs: lighttpd
│   │       - Mounts: lighttpd.conf, index.html
│   │       - Exposes: Port 80
│   │
│   ├── lighttpd.conf
│   │   └── Web server configuration
│   │       - Document root: /var/www/html
│   │       - Port: 80
│   │       - MIME types: html, js, css, json
│   │       - Logs to stdout/stderr (container-friendly)
│   │
│   └── index.html (PROVIDED)
│       └── Frontend UI
│           - Displays: "[Name] has reached milestone 2!"
│           - Fetches: /api/name endpoint
│           - Updates: dynamically on load
│
├── api/
│   │
│   ├── Dockerfile
│   │   └── Builds FastAPI image
│   │       - Base: python:3.11-slim
│   │       - Installs: dependencies from requirements.txt
│   │       - Copies: app code
│   │       - Exposes: Port 8000
│   │       - Runs: uvicorn server
│   │
│   ├── requirements.txt
│   │   └── Python dependencies
│   │       - fastapi: REST framework
│   │       - uvicorn: ASGI server
│   │       - pymongo: MongoDB driver
│   │
│   └── app/
│       │
│       └── main.py
│           └── FastAPI application
│               - CORS: Allows cross-origin requests
│               - MongoDB: Lazy connection (connects on first request)
│               - Endpoints:
│                 - GET /api/name → {"name": "..."}
│                 - GET /api/container-id → {"container_id": "..."}
│                 - GET /health → {"status": "ok"}
│
└── db/
    │
    └── init/
        │
        └── init.js
            └── MongoDB initialization script
                - Runs on container first start
                - Creates database: fkdb
                - Creates collection: profile
                - Inserts default document: {key:"name", value:"Frank Koch"}
```

---

## Running the Stack

### Manual Commands (Docker Desktop Terminal)

#### Command 1: Build Images

```bash
# Navigate to project folder
cd fk-webserver

# Build API and Frontend images from Dockerfiles
docker-compose build

# Output:
# Building fk-api ... done
# Building fk-frontend ... done
# 
# Images created:
# - fk-webserver-fk-api:latest (built from api/Dockerfile)
# - fk-webserver-fk-frontend:latest (built from frontend/Dockerfile)
# - mongo:6 (pulled from Docker Hub)
```

#### Command 2: Start All Containers

```bash
# Start services in detached mode (-d = background)
docker-compose up -d

# Output:
# Creating fk-mongo ... done
# Creating fk-api ... done
# Creating fk-frontend ... done
#
# Containers running:
# - fk-mongo (MongoDB)
# - fk-api (FastAPI)
# - fk-frontend (Lighttpd)
```

#### Command 3: Check Container Status

```bash
# View running containers
docker-compose ps

# Output:
# NAME              COMMAND                  SERVICE      STATUS
# fk-mongo          docker-entrypoint.s...   fk-mongo     Up 15 seconds
# fk-api            python -m uvicorn...     fk-api       Up 10 seconds
# fk-frontend       lighttpd -D -f ...       fk-frontend  Up 5 seconds
```

#### Command 4: View Logs

```bash
# View logs from all services
docker-compose logs

# View live logs (follow mode)
docker-compose logs -f

# View logs for specific service
docker-compose logs fk-api
docker-compose logs fk-mongo
docker-compose logs fk-frontend
```

#### Command 5: Access Frontend

```bash
# Browser access
# 1. Open browser
# 2. Go to: http://localhost:8080
# 3. You should see: "[Name] has reached milestone 2!"
# 4. The name is fetched from API → MongoDB

# Or via PowerShell
Invoke-WebRequest http://localhost:8080
```

#### Command 6: Test API Endpoints

```powershell
# Test name endpoint
Invoke-WebRequest -Uri http://localhost:8000/api/name -UseBasicParsing
# Returns: {"name":"Frank Koch"}

# Test container-id endpoint
Invoke-WebRequest -Uri http://localhost:8000/api/container-id -UseBasicParsing
# Returns: {"container_id":"fk-api"}

# Test health endpoint
Invoke-WebRequest -Uri http://localhost:8000/health -UseBasicParsing
# Returns: {"status":"ok"}
```

#### Command 7: Access MongoDB

```bash
# Open MongoDB shell in container
docker-compose exec fk-mongo mongosh

# Inside MongoDB shell:
> use fkdb
> db.profile.find()
# Output: { _id: ..., key: "name", value: "Frank Koch" }

# Update the name
> db.profile.updateOne({key:"name"}, {$set:{value:"Jane Doe"}})

# Verify and refresh browser
# Frontend should now show: "Jane Doe has reached milestone 2!"
```

#### Command 8: Stop All Containers

```bash
# Stop containers (keeps data)
docker-compose stop

# Output:
# Stopping fk-frontend ... done
# Stopping fk-api ... done
# Stopping fk-mongo ... done
```

#### Command 9: Restart Stack

```bash
# Start again (data persists if volume not deleted)
docker-compose start
```

#### Command 10: Clean Up

```bash
# Stop and remove containers, networks
docker-compose down

# Also remove volumes (MongoDB data will be lost)
docker-compose down -v
```

---

## Verification & Testing

### Test Checklist

#### ✅ Docker Images Built

```bash
docker images | grep fk-webserver

# Expected:
# fk-webserver-fk-api         latest    xxx    2 days ago
# fk-webserver-fk-frontend    latest    xxx    2 days ago
```

#### ✅ Containers Running

```bash
docker-compose ps

# All 3 containers should show "Up"
```

#### ✅ Ports Accessible

```powershell
# Frontend
Test-NetConnection -ComputerName localhost -Port 8080
# Status: TcpTestSucceeded

# API
Test-NetConnection -ComputerName localhost -Port 8000
# Status: TcpTestSucceeded

# MongoDB
Test-NetConnection -ComputerName localhost -Port 27017
# Status: TcpTestSucceeded
```

#### ✅ API Endpoints Working

```powershell
# Test all 3 endpoints
curl http://localhost:8000/api/name
curl http://localhost:8000/api/container-id
curl http://localhost:8000/health

# All should return valid JSON
```

#### ✅ Frontend Loads

```powershell
# Open browser
Start-Process http://localhost:8080

# Expected:
# Page title: "Milestone 2"
# Heading: "Frank Koch has reached milestone 2!"
```

#### ✅ MongoDB Connected

```bash
docker-compose logs fk-api | grep "MongoDB connected"

# Expected: "✓ MongoDB connected successfully"
```

### Integration Test

```bash
# 1. Update MongoDB via CLI
docker-compose exec fk-mongo mongosh

# Inside mongo shell:
use fkdb
db.profile.updateOne({key:"name"}, {$set:{value:"Test Person"}})
exit

# 2. Verify API returns new name
curl http://localhost:8000/api/name
# Output: {"name":"Test Person"}

# 3. Refresh browser
# Page should now show: "Test Person has reached milestone 2!"
```

---

## Troubleshooting

### Issue 1: Container Won't Start

```bash
# Check logs
docker-compose logs fk-api

# Common causes:
# - Port already in use
# - MongoDB not ready yet

# Solution: Wait 10 seconds and restart
docker-compose restart
```

### Issue 2: API Can't Connect to MongoDB

```bash
# Check MongoDB logs
docker-compose logs fk-mongo

# MongoDB inside container uses hostname: fk-mongo
# (Not localhost - Docker DNS resolves service names)

# Verify connection in API logs
docker-compose logs fk-api
# Should see: "✓ MongoDB connected successfully"
```

### Issue 3: Port Already in Use

```bash
# Check what's using the port (Windows)
netstat -ano | findstr :8080

# Kill the process (replace PID)
taskkill /PID <PID> /F

# Or change ports in docker-compose.yaml
# Change: 8080:80 to something else like 8081:80
```

### Issue 4: Frontend Shows "Loading..."

```bash
# Browser console shows CORS error?
# Or fetch fails?

# Check API is running
docker-compose logs fk-api

# Check browser network requests (F12 → Network tab)
# Should see /api/name request to http://localhost:8000

# Verify API response
curl http://localhost:8000/api/name
```

### Issue 5: Data Lost After Restart

```bash
# MongoDB uses ephemeral storage by default in docker-compose.yaml
# Volume is not persisted

# To persist data, add to docker-compose.yaml:
# volumes:
#   - mongo_data:/data/db
# 
# And add at bottom:
# volumes:
#   mongo_data:

# Or use named volume approach
```

### Issue 6: Can't Access Container Shell

```bash
# Run command inside container
docker-compose exec fk-api bash

# Or directly in API container
docker-compose exec fk-api python -c "import pymongo; print(pymongo.__version__)"

# View running processes
docker-compose exec fk-api ps aux
```

---

## Assignment Checklist

### Requirements (10/20 points)

- ✅ **3-container stack:** MongoDB, FastAPI API, Lighttpd Frontend
- ✅ **Frontend HTML:** Serves static page with JavaScript
- ✅ **Dynamic UI:** Shows name from database (updates with page refresh)
- ✅ **API endpoint 1:** GET /api/name → Returns name from MongoDB
- ✅ **API endpoint 2:** GET /api/container-id → Returns container hostname
- ✅ **Database storage:** Persists name in MongoDB collection
- ✅ **Docker:** All services run in containers via Docker Compose
- ✅ **Manual:** Can be set up with `docker-compose up` from terminal

### Files Created

- ✅ `docker-compose.yaml` - Orchestration
- ✅ `api/Dockerfile` - API image
- ✅ `api/requirements.txt` - Python dependencies
- ✅ `api/app/main.py` - FastAPI code
- ✅ `frontend/Dockerfile` - Frontend image
- ✅ `frontend/lighttpd.conf` - Web server config
- ✅ `frontend/index.html` - (Provided)
- ✅ `db/init/init.js` - MongoDB init

### Next Steps (For Extra Points)

To achieve 20/20, this Docker stack would be migrated to Kubernetes with:

- Kubeadm cluster deployment (+10 base points)
- HTTPS with cert-manager (+2 points)
- Extra worker node with API scaling (+1 point)
- Healthcheck probes (+1 point)
- Prometheus monitoring (+2 points)
- ArgoCD GitOps via Helm (+4 points)

See **ASSIGNMENT-GUIDE.md**, **HELM-ARGOCD-PROMETHEUS.md**, and other documentation for Kubernetes implementation.

---

*Last verified: 2026-02-22*
*Technology: Docker Desktop, Docker Compose*
*Status: ✅ Baseline stack fully operational*
