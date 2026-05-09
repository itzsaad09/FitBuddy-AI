# ── Runtime image ─────────────────────────────────────────────────────────────
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

# Build context is the REPO ROOT on Render, so paths are relative to that
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ .

# Render injects $PORT at runtime; default to 10000 for local testing
ENV PORT=10000

EXPOSE ${PORT}

# gunicorn for production — 1 worker and 1 thread is safest for MediaPipe on Render Free Tier
CMD gunicorn --bind 0.0.0.0:${PORT} --workers 1 --threads 1 --timeout 120 main:app
