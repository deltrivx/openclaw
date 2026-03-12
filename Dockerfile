# syntax=docker/dockerfile:1

# Debian-based image with GitHub CLI (gh) + Chromium stack + Playwright (可交互) 预装
# Works on linux/amd64 and linux/arm64; suitable for buildx

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Base deps + GitHub CLI (official APT) + Chromium/OCR/PDF/Node
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

# Playwright 预装（含浏览器依赖 + Chromium 引擎）；缓存到 /ms-playwright 以便运行时使用
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    CHROME_PATH=/usr/bin/chromium
RUN npm i -g playwright \
 && npx --yes playwright install --with-deps chromium \
 && npx --yes playwright install-deps chromium || true

# Verify tools（不因失败中断）
RUN gh --version && git --version && chromium --version || true
RUN node -e "try{require('playwright');console.log('playwright ok')}catch(e){console.log(e?.message||'no playwright')}"

# Default working dir
WORKDIR /app
CMD ["bash"]
