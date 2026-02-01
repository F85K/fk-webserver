# FK Webstack - API Service (FastAPI)
# Builds a Python-based REST API that connects to MongoDB
# 
# Build: docker build -t fk-api:1.0 .
# Run:   docker run -p 8000:8000 -e MONGO_URL=mongodb://mongo:27017 fk-api:1.0

# Stage 1: Python runtime
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies (minimal for security)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ ./app/

# Expose API port
EXPOSE 8000

# Health check for Kubernetes
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run FastAPI with uvicorn
# - host 0.0.0.0 allows connections from outside container
# - port 8000 matches EXPOSE
# - workers 1 (simple setup, can increase for production)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
