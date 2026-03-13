# syntax=docker/dockerfile:1.7

############################
# Builder: build OpenClaw from upstream source (for source-level 汉化 patching)
############################
FROM node:20-bookworm AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG OPENCLAW_REF=main

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates curl bash \
 && rm -rf /var/lib/apt/lists/*

# pnpm
RUN corepack enable && corepack prepare pnpm@9.15.0 --activate

WORKDIR /src
RUN git clone --depth 1 --branch ${OPENCLAW_REF} https://github.com/openclaw/openclaw.git .

# TODO(zh-cn): apply patches here in future iterations.
# For now, we prove the build pipeline works.

RUN pnpm install --frozen-lockfile
RUN pnpm build:docker

############################
# Runtime: Debian base + OpenClaw dist + toolchain
############################
FROM debian:12-slim

ARG DEBIAN_FRONTEND=noninteractive

# base runtime deps
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git unzip xz-utils bash tini \
    ffmpeg \
    tesseract-ocr tesseract-ocr-chi-sim \
    ocrmypdf \
    poppler-utils \
    fonts-noto-cjk fonts-noto-color-emoji \
    python3 python3-pip \
 && rm -rf /var/lib/apt/lists/*

# locale for Chinese defaults
ENV LANG=zh_CN.UTF-8
ENV LC_ALL=zh_CN.UTF-8

# Node 20 (runtime)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get update \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

# Copy OpenClaw build output
WORKDIR /opt/openclaw
COPY --from=builder /src/dist ./dist
COPY --from=builder /src/openclaw.mjs ./openclaw.mjs
COPY --from=builder /src/package.json ./package.json
COPY --from=builder /src/README.md ./README.upstream.md

# Provide CLI entry
RUN ln -sf /opt/openclaw/openclaw.mjs /usr/local/bin/openclaw \
 && chmod +x /usr/local/bin/openclaw

# ClawHub + Playwright
RUN npm i -g clawhub@latest \
 && npm i -g playwright@1.58.2

# Bundle Playwright Chromium, expose /usr/bin/chromium
ENV NODE_PATH=/usr/local/lib/node_modules
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN npx playwright install chromium \
 && CHROME_BIN="$(find /ms-playwright -type f \( -path '*/chrome-linux*/chrome' -o -path '*/chrome-linux*/chrome-wrapper' -o -path '*/chrome-linux64/chrome' \) 2>/dev/null | head -n 1)" \
 && test -n "$CHROME_BIN" \
 && ln -sf "$CHROME_BIN" /usr/bin/chromium

# Python packages (system python; user accepted --break-system-packages)
RUN python3 -m pip install --no-cache-dir --break-system-packages --upgrade pip \
 && python3 -m pip install --no-cache-dir --break-system-packages --only-binary=:all: faster-whisper ctranslate2 \
 && python3 -m pip install --no-cache-dir --break-system-packages "playwright>=1.50,<2" edge-tts pyyaml

ENV TERM=xterm-256color
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["openclaw","gateway","start"]
