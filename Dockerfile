# syntax=docker/dockerfile:1
# OpenClaw Enhanced Image (minimal buildable baseline)
# Phase 1 (onboard zh-CN groundwork): add repo-local translations/ + scripts/i18n for later patching.

FROM ghcr.io/openclaw/openclaw:latest

# Path used by CI to inject built dist
COPY injected/ /injected/

USER root

ENV TZ=Asia/Shanghai \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh:en \
    LC_ALL=zh_CN.UTF-8

# Playwright: use system Chromium; never download browsers at runtime
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg \
    locales tzdata \
    fonts-noto-cjk fonts-noto-color-emoji \
    chromium \
    ffmpeg \
    tesseract-ocr tesseract-ocr-chi-sim \
    ocrmypdf \
    poppler-utils \
    jq \
 && install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg \
      -o /etc/apt/keyrings/tailscale-archive-keyring.gpg \
 && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list \
      -o /etc/apt/sources.list.d/tailscale.list \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tailscale \
 && sed -i 's/^# *zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen \
 && locale-gen zh_CN.UTF-8 \
 && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
 && echo $TZ > /etc/timezone \
 && rm -rf /var/lib/apt/lists/*

# Repo-local translation assets / patch scripts
COPY translations/ /opt/openclaw-enhanced/translations/
COPY scripts/ /opt/openclaw-enhanced/scripts/

# NOTE: We previously attempted to patch compiled JS output for zh-CN onboarding.
# That approach caused runtime SyntaxError on some deployments (e.g., Unraid).
# Keep the image stable: do not patch compiled output at build time.

# Optional: inject rebuilt upstream dist from CI artifact (mounted into build context as ./injected)
ARG INJECT_DIST=0
RUN /bin/bash -lc 'set -euo pipefail; if [ "$INJECT_DIST" = "1" ] && [ -d /injected/dist ]; then echo "[inject] overlaying /app/dist (keep base assets)"; mkdir -p /app/dist; cp -a /injected/dist/. /app/dist/; fi'

# Entrypoint: attempt config self-heal (doctor --fix) then start gateway
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
