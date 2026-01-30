# Python image voor FastAPI
FROM python:3.11-slim

# Werkdirectory
WORKDIR /app

# Dependencies installeren
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Applicatie code kopiëren
COPY app /app/app

# Expose poort 8000
EXPOSE 8000

# Start de API met Uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
