# syntax=docker/dockerfile:1
# OpenClaw Enhanced Image (minimal buildable baseline)
# Phase 1 (onboard zh-CN groundwork): add repo-local translations/ + scripts/i18n for later patching.

FROM ghcr.io/openclaw/openclaw:latest

# NOTE: We inject a CI-built dist artifact to get maximum zh-CN coverage (incl. control-ui).
# This artifact is produced in GitHub Actions and should match upstream build outputs.

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
 && install -d -m 0755 /usr/share/keyrings \
 && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg \
      -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
 && printf '%s\n' 'deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian bookworm main' \
      > /etc/apt/sources.list.d/tailscale.list \
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

# ------------------------------------------------------------
# Inject CI-built upstream dist (includes control-ui) for best zh-CN coverage.
# Generated during GitHub Actions in `.github/workflows/docker.yml` and staged under `ci-dist/`.
# ------------------------------------------------------------
# The artifact keeps its original paths (uploaded from upstream-src/*), so it lands under ci-dist/upstream-src/.
COPY ci-dist/upstream-src/dist/ /app/dist/
COPY ci-dist/upstream-src/openclaw.mjs /app/openclaw.mjs
COPY ci-dist/upstream-src/package.json /app/package.json

# Entrypoint: attempt config self-heal (doctor --fix) then start gateway
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
