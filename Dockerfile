# syntax=docker/dockerfile:1.7

# OpenClaw enhanced base — 稳定构建 + 预装 CLI/Playwright
# - gh CLI + Chromium/ffmpeg + Tesseract/OCRmyPDF/Poppler + Node.js
# - Playwright (interactive) + OpenClaw CLI（可参数化版本）
# - 前台网关；可选用代理加速

FROM debian:bookworm-slim

ARG OPENCLAW_VERSION=latest
ENV DEBIAN_FRONTEND=noninteractive \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    CHROME_PATH=/usr/bin/chromium \
    OPENCLAW_LOG_LEVEL=info \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false

# -------- System deps + gh (APT) --------
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

# -------- npm/git 配置：避免 ssh 依赖 + 提高稳健性 --------
RUN git config --global url."https://github.com/".insteadOf "git@github.com:" \
 && git config --global url."https://github.com/".insteadOf "ssh://git@github.com/" \
 && git config --global advice.detachedHead false \
 && npm config set fetch-retry-maxtimeout 600000 \
 && npm config set fetch-retry-mintimeout 20000 \
 && npm config set fetch-retries 3 \
 && npm config set prefer-online true \
 && npm config set fund false \
 && npm config set audit false
# 可选国内镜像（如需）：
# RUN npm config set registry https://registry.npmmirror.com

# -------- 预装 Playwright + OpenClaw CLI （带重试） --------
RUN set -eux; \
    for i in 1 2 3; do \
      npm i -g --unsafe-perm=true playwright && break || (echo "[warn] npm i playwright retry #$i" >&2; sleep 5); \
    done; \
    for i in 1 2 3; do \
      npm i -g --unsafe-perm=true openclaw@${OPENCLAW_VERSION} && break || (echo "[warn] npm i openclaw@${OPENCLAW_VERSION} retry #$i" >&2; sleep 5); \
    done; \
    npx --yes playwright install --with-deps chromium || npx --yes playwright install chromium; \
    npx --yes playwright install-deps chromium || true

# -------- 基本自检（非致命；修正引号与 || true） --------
RUN gh --version || true \
 && chromium --version || true \
 && node -e 'try{require("playwright");console.log("playwright ok")}catch(e){console.log("no playwright")}' || true \
 && openclaw --version || true

# -------- 网关端口 + 健康检查 --------
EXPOSE 18789
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
  CMD curl -fsS http://127.0.0.1:18789/ >/dev/null || exit 1

# -------- 默认前台网关（容器友好） --------
WORKDIR /app
CMD ["bash","-lc","OPENCLAW_LOG_LEVEL=${OPENCLAW_LOG_LEVEL} openclaw gateway"]
