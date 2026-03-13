# syntax=docker/dockerfile:1

# OpenClaw enhanced: gh CLI + Chromium stack + Playwright (interactive) + OpenClaw CLI (preinstalled)
# Starts the OpenClaw gateway in foreground by default (container-friendly; no systemd required)

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    CHROME_PATH=/usr/bin/chromium \
    OPENCLAW_LOG_LEVEL=info

# System deps + gh (official APT) + Chromium/OCR/PDF/Node
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gnupg \
      git \
      openssh-client \
      bash \
      chromium \
      chromium-common \
      chromium-driver \
      ffmpeg \
      tesseract-ocr \
      tesseract-ocr-chi-sim \
      ocrmypdf \
      poppler-utils \
      qpdf \
      ghostscript \
      pngquant \
      nodejs npm \
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# Preinstall Playwright (CLI + Chromium engine) and OpenClaw CLI
RUN npm i -g playwright openclaw@latest \
 && npx --yes playwright install --with-deps chromium \
 && npx --yes playwright install-deps chromium || true

# Basic verifications (non-fatal)
RUN gh --version || true \
 && chromium --version || true \
 && node -e "try{require('playwright');console.log('playwright ok')}catch(e){console.log('no playwright')}" \
 && openclaw --version || true

# Expose OpenClaw gateway port
EXPOSE 18789

# Healthcheck: try HTTP on gateway
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
  CMD curl -fsS http://127.0.0.1:18789/ >/dev/null || exit 1

# Default working dir (mounted by users as needed)
WORKDIR /app

# Default command: run OpenClaw gateway in foreground (container friendly)
CMD ["bash", "-lc", "OPENCLAW_LOG_LEVEL=${OPENCLAW_LOG_LEVEL} openclaw gateway"]
