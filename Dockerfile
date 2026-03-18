# syntax=docker/dockerfile:1
# OpenClaw Enhanced Image (minimal buildable baseline)
# This phase intentionally avoids COPY of non-existent paths; we will add onboard/webui/cli and translations in later phases.

FROM ghcr.io/openclaw/openclaw:latest

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
    ca-certificates curl \
    locales tzdata \
    fonts-noto-cjk fonts-noto-color-emoji \
    chromium \
    ffmpeg \
    tesseract-ocr tesseract-ocr-chi-sim \
    ocrmypdf \
    poppler-utils \
    jq \
 && sed -i 's/^# *zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen \
 && locale-gen zh_CN.UTF-8 \
 && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
 && echo $TZ > /etc/timezone \
 && rm -rf /var/lib/apt/lists/*

# Preserve upstream command
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
