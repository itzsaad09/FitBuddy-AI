# ── Stage: runtime ───────────────────────────────────────────────────────────
FROM python:3.10-slim

WORKDIR /app

# System dependencies required by OpenCV (headless) and MediaPipe
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libgl1 \
    libgomp1 \
    libgthread-2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies first (layer-cache friendly)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY . .

# Render injects $PORT at runtime; default to 10000 for local testing
ENV PORT=10000

EXPOSE ${PORT}

# Use gunicorn for production — Flask dev server is NOT suitable for Render
CMD gunicorn --bind 0.0.0.0:${PORT} --workers 1 --threads 2 --timeout 120 app:app
