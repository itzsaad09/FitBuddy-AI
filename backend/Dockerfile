# Use a lightweight Python image
FROM python:3.10-slim

# Install system dependencies for OpenCV and MediaPipe
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install dependencies first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

# Set environment variables for production
ENV PORT=10000
ENV PYTHONUNBUFFERED=1

# Expose the port Render expects
EXPOSE 10000

# Start with Gunicorn (using gthread workers for MediaPipe stability)
CMD gunicorn --bind 0.0.0.0:$PORT --workers 1 --threads 4 --worker-class gthread main:app
