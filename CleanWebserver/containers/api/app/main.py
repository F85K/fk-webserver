#!/usr/bin/env python3
"""
FK Webstack - FastAPI Backend
Serves JSON API endpoints for frontend to consume

Endpoints:
  GET /api/name - Returns name from MongoDB
  GET /api/container-id - Returns container ID
  GET /health - Health check (liveness/readiness probes)
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import pymongo
import os
import socket
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI
app = FastAPI(title="FK Webstack API", version="1.0")

# Enable CORS so frontend can call from different domain
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database configuration from environment variables
MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017")
MONGO_DB = os.getenv("MONGO_DB", "fkdb")
MONGO_COLLECTION = os.getenv("MONGO_COLLECTION", "profile")
DEFAULT_NAME = os.getenv("DEFAULT_NAME", "Frank Koch")

# Get container hostname (same as container ID in Kubernetes)
CONTAINER_ID = socket.gethostname()

def get_mongo_connection():
    """Create connection to MongoDB"""
    try:
        client = pymongo.MongoClient(MONGO_URL, serverSelectionTimeoutMS=5000)
        # Test connection
        client.admin.command('ping')
        logger.info(f"✓ Connected to MongoDB at {MONGO_URL}")
        return client
    except Exception as e:
        logger.error(f"✗ Failed to connect to MongoDB: {e}")
        return None

# Initialize MongoDB connection
mongo_client = get_mongo_connection()

@app.get("/")
async def root():
    """Root endpoint - API info"""
    return {
        "status": "ok",
        "service": "FK Webstack API",
        "version": "1.0",
        "container_id": CONTAINER_ID
    }

@app.get("/health")
async def health_check():
    """
    Health check endpoint for Kubernetes liveness/readiness probes
    Returns 200 if healthy, else 500
    """
    try:
        # Try to connect to MongoDB
        if mongo_client is None:
            mongo_client_temp = get_mongo_connection()
            if mongo_client_temp is None:
                return {"status": "error", "reason": "MongoDB connection failed"}, 500
        else:
            mongo_client.admin.command('ping')
        
        return {"status": "ok"}
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return {"status": "error", "reason": str(e)}, 500

@app.get("/api/name")
async def get_name():
    """
    Get name from MongoDB
    Queries collection for first document with 'name' field
    Returns: {"name": "Frank Koch"}
    """
    try:
        if mongo_client is None:
            return {"error": "MongoDB not connected"}, 500
        
        db = mongo_client[MONGO_DB]
        collection = db[MONGO_COLLECTION]
        
        # Find profile document (first document with 'name' field)
        profile = collection.find_one({"name": {"$exists": True}})
        
        if profile and "name" in profile:
            name = profile["name"]
            logger.info(f"✓ Retrieved name from MongoDB: {name}")
            return {"name": name}
        else:
            # If not found, return default and create entry
            logger.warning(f"Profile not found, creating with default name: {DEFAULT_NAME}")
            collection.insert_one({"name": DEFAULT_NAME})
            return {"name": DEFAULT_NAME}
            
    except Exception as e:
        logger.error(f"✗ Error getting name: {e}")
        return {"error": str(e)}, 500

@app.get("/api/container-id")
async def get_container_id():
    """
    Get container ID/hostname
    Returns: {"container_id": "fk-api-77c9b86cb4-xyz"}
    """
    return {"container_id": CONTAINER_ID}

@app.get("/api/stats")
async def get_stats():
    """
    Get API statistics
    Returns: {"uptime": ..., "container": ..., "database": ...}
    """
    return {
        "container_id": CONTAINER_ID,
        "database": MONGO_DB,
        "collection": MONGO_COLLECTION,
        "status": "operational"
    }

# Startup event
@app.on_event("startup")
async def startup_event():
    logger.info("========================================")
    logger.info("FK Webstack API starting up...")
    logger.info(f"Container ID: {CONTAINER_ID}")
    logger.info(f"MongoDB URL: {MONGO_URL}")
    logger.info(f"Database: {MONGO_DB}")
    logger.info("========================================")

# Shutdown event
@app.on_event("shutdown")
async def shutdown_event():
    logger.info("FK Webstack API shutting down...")
    if mongo_client:
        mongo_client.close()

if __name__ == "__main__":
    # For development only - use Dockerfile to run with uvicorn
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
