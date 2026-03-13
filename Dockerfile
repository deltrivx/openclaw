# syntax=docker/dockerfile:1.7

# OpenClaw enhanced base — fast rebuilds
# - gh CLI + Chromium/ffmpeg + Tesseract/OCRmyPDF/Poppler + Node.js
# - Playwright (interactive) + OpenClaw CLI (preinstalled)
# - Foreground gateway; BuildKit cache mounts for faster builds

FROM debian:bookworm-slim

ARG OPENCLAW_VERSION=latest
ENV DEBIAN_FRONTEND=noninteractive \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    CHROME_PATH=/usr/bin/chromium \
    OPENCLAW_LOG_LEVEL=info \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false

# -------- System deps + gh (APT) + Chromium/OCR/PDF/Node --------
# 只缓存 /var/cache/apt（不要缓存 /var/lib/apt，避免锁冲突）
RUN --mount=type=cache,target=/var/cache/apt \
    set -eux; \
    # 清理潜在锁 & 修复未完成的 dpkg 配置
    rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock-frontend || true; \
    dpkg --configure -a || true; \
    # apt-get update（带重试与锁清理）
    for i in 1 2 3; do \
      apt-get update && break || ( \
        echo "[warn] apt-get update failed, retry #$i" >&2; \
        sleep 2; \
        rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock-frontend || true; \
        dpkg --configure -a || true \
      ); \
    done; \
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
    for i in 1 2 3; do \
      apt-get update && break || ( \
        echo "[warn] apt-get update (gh repo) failed, retry #$i" >&2; \
        sleep 2; \
        rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock-frontend || true; \
        dpkg --configure -a || true \
      ); \
    done; \
    apt-get install -y --no-install-recommends gh; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# 避免 npm 依赖走 ssh:// 或 git@ 形式
RUN git config --global url."https://github.com/".insteadOf "git@github.com:" \
 && git config --global url."https://github.com/".insteadOf "ssh://git@github.com/" \
 && git config --global advice.detachedHead false

# -------- Preinstall Playwright + OpenClaw CLI --------
RUN --mount=type=cache,target=/root/.npm \
    set -eux; \
    npm i -g playwright openclaw@${OPENCLAW_VERSION}; \
    npx --yes playwright install --with-deps chromium; \
    npx --yes playwright install-deps chromium || true

# -------- Basic verifications (non-fatal) --------
RUN gh --version || true \
 && chromium --version || true \
 && node -e "try{require('playwright');console.log('playwright ok')}catch(e){console.log('no playwright')}" \
 && openclaw --version || true

# -------- Gateway port + healthcheck --------
EXPOSE 18789
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
  CMD curl -fsS http://127.0.0.1:18789/ >/dev/null || exit 1

# -------- Defaults --------
WORKDIR /app
# 前台网关（容器友好）；如有配置文件：-e OPENCLAW_CONFIG=/root/.openclaw/config.yaml
CMD ["bash","-lc","OPENCLAW_LOG_LEVEL=${OPENCLAW_LOG_LEVEL} openclaw gateway"]
