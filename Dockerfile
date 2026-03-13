# syntax=docker/dockerfile:1.7

# OpenClaw enhanced base — 简化APT层，避免锁冲突与语法问题
# - gh CLI + Chromium/ffmpeg + Tesseract/OCRmyPDF/Poppler + Node.js
# - Playwright + OpenClaw CLI 预装
# - 前台网关；BuildKit 可加速（可选）

FROM debian:bookworm-slim

ARG OPENCLAW_VERSION=latest
ENV DEBIAN_FRONTEND=noninteractive \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    CHROME_PATH=/usr/bin/chromium \
    OPENCLAW_LOG_LEVEL=info \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false

# -------- 最稳APT层（不做锁文件花活，避免“true”误拼接导致语法错） --------
RUN set -eux; \
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
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# 避免 npm 依赖走 ssh:// 或 git@ 形式
RUN git config --global url."https://github.com/".insteadOf "git@github.com:" \
 && git config --global url."https://github.com/".insteadOf "ssh://git@github.com/" \
 && git config --global advice.detachedHead false

# -------- 预装 Playwright + OpenClaw CLI --------
RUN set -eux; \
    npm i -g playwright openclaw@${OPENCLAW_VERSION}; \
    npx --yes playwright install --with-deps chromium; \
    npx --yes playwright install-deps chromium || true

# -------- 基本自检（非致命） --------
RUN gh --version || true \
 && chromium --version || true \
 && node -e "try{require('playwright');console.log('playwright ok')}catch(e){console.log('no playwright')}" \
 && openclaw --version || true

# -------- 网关端口 + 健康检查 --------
EXPOSE 18789
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
  CMD curl -fsS http://127.0.0.1:18789/ >/dev/null || exit 1

# -------- 默认前台网关（容器友好） --------
WORKDIR /app
CMD ["bash","-lc","OPENCLAW_LOG_LEVEL=${OPENCLAW_LOG_LEVEL} openclaw gateway"]
