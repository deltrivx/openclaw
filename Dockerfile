# syntax=docker/dockerfile:1.7

# Enhanced image based on upstream OpenClaw runtime image.
FROM ghcr.io/openclaw/openclaw:latest

USER root
WORKDIR /app

# System deps (browser, media, OCR) + small utilities
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      chromium \
      ffmpeg \
      tesseract-ocr \
      tesseract-ocr-chi-sim \
      ocrmypdf \
      poppler-utils \
      jq \
      ca-certificates; \
    rm -rf /var/lib/apt/lists/*

# Playwright: use system Chromium
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium

# Copy prebuilt Control UI (built in GitHub Actions)
# OpenClaw expects dist/control-ui/index.html
COPY control-ui/ /app/dist/control-ui/

# Back to non-root (matches upstream)
USER node

