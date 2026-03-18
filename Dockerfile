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
      ca-certificates \
      wget \
      libespeak-ng1; \
    rm -rf /var/lib/apt/lists/*

# Piper (offline TTS)
# We download a prebuilt piper binary and the zh_CN-huayan-medium model.
RUN set -eux; \
    mkdir -p /opt/piper /opt/piper/models /tmp/piper; \
    wget -O /tmp/piper/piper_linux_x86_64.tar.gz \
      "https://github.com/rhasspy/piper/releases/latest/download/piper_linux_x86_64.tar.gz"; \
    tar -xzf /tmp/piper/piper_linux_x86_64.tar.gz -C /opt/piper; \
    rm -rf /tmp/piper; \
    # Ensure binary is executable (path differs by release packaging)
    if [ -f /opt/piper/piper ]; then chmod +x /opt/piper/piper; fi; \
    if [ -f /opt/piper/bin/piper ]; then chmod +x /opt/piper/bin/piper; fi; \
    wget -O "/opt/piper/models/zh_CN-huayan-medium.onnx" \
      "https://huggingface.co/csukuangfj/vits-piper-zh_CN-huayan-medium/resolve/main/zh_CN-huayan-medium.onnx"; \
    wget -O "/opt/piper/models/zh_CN-huayan-medium.onnx.json" \
      "https://huggingface.co/csukuangfj/vits-piper-zh_CN-huayan-medium/resolve/main/zh_CN-huayan-medium.onnx.json";

# Playwright: use system Chromium
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium

# Copy prebuilt Control UI (built in GitHub Actions)
# OpenClaw expects dist/control-ui/index.html
COPY control-ui/ /app/dist/control-ui/

# TTS server (OpenAI-compatible): http://127.0.0.1:18793/v1/audio/speech
COPY tts-server.mjs /app/tts-server.mjs
# Piper binary location varies by release packaging; prefer /opt/piper/piper, fallback to /opt/piper/bin/piper
ENV PIPER_BIN=/opt/piper/piper \
    PIPER_BIN_FALLBACK=/opt/piper/bin/piper \
    PIPER_MODELS_DIR=/opt/piper/models \
    PIPER_DEFAULT_VOICE=zh_CN-huayan-medium \
    TTS_BIND=127.0.0.1 \
    TTS_PORT=18793

# Supervisor: run TTS server + OpenClaw gateway
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Run as root (per user request)
USER root

CMD ["/app/entrypoint.sh"]

