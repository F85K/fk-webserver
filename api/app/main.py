# FastAPI app die data uit MongoDB leest
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pymongo import MongoClient
from pymongo.errors import ServerSelectionTimeoutError, ConnectionFailure
import os
import socket
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Config via environment variables (met defaults)
MONGO_URL = os.getenv("MONGO_URL", "mongodb://fk-mongodb:27017")
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

# MongoDB client - lazy connection with timeout
# This will NOT connect immediately, only when first query is made
client = None
collection = None

def get_db_collection():
    """Lazy MongoDB connection - only connect when needed"""
    global client, collection
    if client is None:
        logger.info(f"Connecting to MongoDB at {MONGO_URL}")
        client = MongoClient(MONGO_URL, serverSelectionTimeoutMS=5000, connectTimeoutMS=5000)
        try:
            # Test connection
            client.admin.command('ping')
            logger.info("✓ MongoDB connected successfully")
        except (ServerSelectionTimeoutError, ConnectionFailure) as e:
            logger.error(f"✗ MongoDB connection failed: {e}")
            client = None
            return None
        collection = client[MONGO_DB][MONGO_COLLECTION]
    return collection

# Helper: haal naam uit MongoDB (of fallback)
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
