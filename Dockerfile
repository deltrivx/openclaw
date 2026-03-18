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
      unzip \
      coreutils \
      libespeak-ng1 \
      npm; \
    rm -rf /var/lib/apt/lists/*

# Piper (offline TTS)
# We download a prebuilt piper binary and the zh_CN-huayan-medium model.
RUN set -eux; \
    mkdir -p /opt/piper /opt/piper/bin /opt/piper/models /tmp/piper; \
    wget -O /tmp/piper/piper_linux_x86_64.tar.gz \
      "https://github.com/rhasspy/piper/releases/latest/download/piper_linux_x86_64.tar.gz"; \
    tar -xzf /tmp/piper/piper_linux_x86_64.tar.gz -C /opt/piper; \
    rm -rf /tmp/piper; \
    # Make sure piper binary is executable and available at /opt/piper/bin/piper.
    PIPER_FOUND="$(find /opt/piper -maxdepth 4 -type f -name piper | head -n 1)"; \
    test -n "$PIPER_FOUND"; \
    chmod 755 "$PIPER_FOUND"; \
    ln -sf "$PIPER_FOUND" /opt/piper/bin/piper; \
    chmod 755 /opt/piper/bin/piper; \
    wget -O "/opt/piper/models/zh_CN-huayan-medium.onnx" \
      "https://huggingface.co/csukuangfj/vits-piper-zh_CN-huayan-medium/resolve/main/zh_CN-huayan-medium.onnx"; \
    wget -O "/opt/piper/models/zh_CN-huayan-medium.onnx.json" \
      "https://huggingface.co/csukuangfj/vits-piper-zh_CN-huayan-medium/resolve/main/zh_CN-huayan-medium.onnx.json";

# Playwright: use system Chromium
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium

# ClawHub CLI + Bun runtime (repo README expectation)
RUN npm i -g clawhub && \
    curl -fsSL https://bun.sh/install | bash && \
    ln -sf /root/.bun/bin/bun /usr/local/bin/bun

# Tailscale (optional; eliminates "spawn tailscale ENOENT" when enabled)
COPY install-tailscale.sh /tmp/install-tailscale.sh
RUN bash /tmp/install-tailscale.sh && rm -f /tmp/install-tailscale.sh

# Copy prebuilt Control UI (built in GitHub Actions)
# OpenClaw expects dist/control-ui/index.html
COPY control-ui/ /app/dist/control-ui/

# TTS server (OpenAI-compatible): http://127.0.0.1:18793/v1/audio/speech
COPY tts-server.mjs /app/tts-server.mjs
# Piper binary is normalized to /opt/piper/bin/piper during image build.
ENV PIPER_BIN=/opt/piper/bin/piper \
    PIPER_MODELS_DIR=/opt/piper/models \
    PIPER_DEFAULT_VOICE=zh_CN-huayan-medium \
    TTS_BIND=127.0.0.1 \
    TTS_PORT=18793

# Supervisor: run TTS server + OpenClaw gateway
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Run as root (per user request)
USER root

# Cosmetic: simplify the default interactive shell prompt (avoid showing "root@openclaw")
ENV PS1="openclaw# "
# Make bash respect it (bashrc can override ENV PS1)
RUN printf '\n# cosmetic prompt\nexport PS1="openclaw# "\n' >> /root/.bashrc

CMD ["/app/entrypoint.sh"]

