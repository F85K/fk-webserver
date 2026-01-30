# FastAPI app die data uit MongoDB leest
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pymongo import MongoClient
import os
import socket

# Config via environment variables (met defaults)
MONGO_URL = os.getenv("MONGO_URL", "mongodb://mongo:27017")
MONGO_DB = os.getenv("MONGO_DB", "fkdb")
MONGO_COLLECTION = os.getenv("MONGO_COLLECTION", "profile")
NAME_KEY = os.getenv("NAME_KEY", "name")
DEFAULT_NAME = os.getenv("DEFAULT_NAME", "Frank Koch")

# Maak FastAPI app aan
app = FastAPI(title="FK API")

# CORS aanzetten zodat frontend de API kan lezen
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Voor schoolproject eenvoudig, in productie beperken
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Maak MongoDB client aan
client = MongoClient(MONGO_URL)
collection = client[MONGO_DB][MONGO_COLLECTION]

# Helper: haal naam uit MongoDB (of fallback)
def get_name_from_db() -> str:
    doc = collection.find_one({"key": NAME_KEY})
    if doc and "value" in doc:
        return str(doc["value"])
    return DEFAULT_NAME

# Endpoint: haal naam uit database
@app.get("/api/name")
def read_name():
    name = get_name_from_db()
    return {"name": name}

# Endpoint: haal container/pod ID (hostname) op
@app.get("/api/container-id")
def read_container_id():
    container_id = socket.gethostname()
    return {"container_id": container_id}

# Healthcheck endpoint (voor Kubernetes liveness/readiness)
@app.get("/health")
def healthcheck():
    return {"status": "ok"}
