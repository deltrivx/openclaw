# syntax=docker/dockerfile:1.7

# OpenClaw enhanced base — fast rebuilds
# - gh CLI + Chromium/ffmpeg + Tesseract/OCRmyPDF/Poppler + Node.js
# - Playwright (interactive) preinstalled (Chromium engine cached)
# - OpenClaw CLI preinstalled
# - Foreground gateway by default (container-friendly; no systemd)
# - BuildKit cache mounts for apt/npm to speed up rebuilds

FROM debian:bookworm-slim

ARG OPENCLAW_VERSION=latest
ENV DEBIAN_FRONTEND=noninteractive \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    CHROME_PATH=/usr/bin/chromium \
    OPENCLAW_LOG_LEVEL=info \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false

# --- System deps + gh (official APT) + Chromium/OCR/PDF/Node ---
# Use BuildKit cache for apt to speed up subsequent builds
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg git openssh-client bash \
      chromium chromium-common chromium-driver ffmpeg \
      tesseract-ocr tesseract-ocr-chi-sim \
      ocrmypdf poppler-utils qpdf ghostscript pngquant \
      nodejs npm; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null; \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends gh; \
    rm -rf /var/lib/apt/lists/*

# Avoid npm trying to fetch GitHub repos via ssh:// or git@ form (use HTTPS)
RUN git config --global url."https://github.com/".insteadOf "git@github.com:" \
 && git config --global url."https://github.com/".insteadOf "ssh://git@github.com/" \
 && git config --global advice.detachedHead false

# --- Preinstall Playwright + OpenClaw CLI ---
# Use cached npm dir to speed up rebuilds
RUN --mount=type=cache,target=/root/.npm \
    set -eux; \
    npm i -g playwright openclaw@${OPENCLAW_VERSION}; \
    # Install Chromium engine and deps once (cached at PLAYWRIGHT_BROWSERS_PATH)
    npx --yes playwright install --with-deps chromium; \
    npx --yes playwright install-deps chromium || true

# --- Basic verifications (non-fatal) ---
RUN gh --version || true \
 && chromium --version || true \
 && node -e "try{require('playwright');console.log('playwright ok')}catch(e){console.log('no playwright')}" \
 && openclaw --version || true

# --- Gateway port + healthcheck ---
EXPOSE 18789
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
  CMD curl -fsS http://127.0.0.1:18789/ >/dev/null || exit 1

# --- Defaults ---
WORKDIR /app
# Foreground gateway; supply config with -e OPENCLAW_CONFIG=/root/.openclaw/config.yaml or use --allow-unconfigured
CMD ["bash", "-lc", "OPENCLAW_LOG_LEVEL=${OPENCLAW_LOG_LEVEL} openclaw gateway"]
