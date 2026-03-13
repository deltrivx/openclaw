# syntax=docker/dockerfile:1

# OpenClaw enhanced base: gh CLI + Chromium stack + Playwright (interactive) + OpenClaw CLI (preinstalled)
# Debian-based; suitable for buildx (amd64/arm64 depending on base availability)

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    CHROME_PATH=/usr/bin/chromium

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

# Default working dir
WORKDIR /app

# Default command: keep interactive shell; run with
#  docker run ... ghcr.io/your/image bash -lc 'openclaw gateway start'
CMD ["bash"]
