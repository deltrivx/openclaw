# syntax=docker/dockerfile:1.7

# Base requirement: upstream comes from openclaw/openclaw:latest
FROM openclaw/openclaw:latest

ARG DEBIAN_FRONTEND=noninteractive

# --- System deps ---
# Install: Chromium (for Playwright), ffmpeg, tesseract (chi_sim), ocrmypdf, poppler utils,
# plus runtime libs that Chromium typically needs.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git unzip xz-utils \
    chromium \
    ffmpeg \
    tesseract-ocr tesseract-ocr-chi-sim \
    ocrmypdf \
    poppler-utils \
    fonts-noto-cjk fonts-noto-color-emoji \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2 \
    libpangocairo-1.0-0 libpango-1.0-0 libgtk-3-0 \
 && rm -rf /var/lib/apt/lists/*

# --- Node toolchain (Node 20+) ---
# Upstream may already ship Node; we ensure Node 20 is present and default.
# Prefer Nodesource to avoid distro lag.
RUN if ! node -v 2>/dev/null | grep -q '^v20\.'; then \
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
      && apt-get update \
      && apt-get install -y --no-install-recommends nodejs \
      && rm -rf /var/lib/apt/lists/*; \
    fi

# --- Playwright ---
# Install Playwright and browsers; but since we install system Chromium, we can skip browser download.
# We still install Playwright so OpenClaw browser tooling works.
RUN npm i -g playwright@latest \
 && npx playwright install-deps \
 && true

# --- GitHub CLI (gh) ---
RUN type -p gh >/dev/null 2>&1 || ( \
      mkdir -p /etc/apt/keyrings \
      && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
      && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
      && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
      && apt-get update \
      && apt-get install -y --no-install-recommends gh \
      && rm -rf /var/lib/apt/lists/* \
    )

# --- ClawHub CLI (skill manager) ---
# Officially installed via npm.
RUN npm i -g clawhub@latest

# --- faster-whisper (binary wheels only) ---
# We intentionally do not build from source. We install Python + pip only as needed to fetch wheels.
# NOTE: faster-whisper depends on ctranslate2; both have prebuilt wheels for manylinux.
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 python3-pip \
 && rm -rf /var/lib/apt/lists/* \
 && python3 -m pip install --no-cache-dir --upgrade pip \
 && python3 -m pip install --no-cache-dir --only-binary=:all: faster-whisper ctranslate2 \
 && true

# --- Piper TTS + Huayan (medium) zh female voice ---
# Piper releases binaries; voices hosted separately. We download into /opt/piper.
# Version pins can be adjusted later.
ARG PIPER_VERSION=1.2.0
RUN mkdir -p /opt/piper \
 && cd /opt/piper \
 && curl -fL -o piper.tar.gz https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/piper_linux_x86_64.tar.gz \
 && tar -xzf piper.tar.gz --strip-components=1 \
 && rm -f piper.tar.gz

# Huayan medium voice (Chinese female). Source: rhasspy/piper-voices
# If URL changes, update here.
RUN mkdir -p /opt/piper/voices/zh \
 && cd /opt/piper/voices/zh \
 && curl -fL -o zh_CN-huayan-medium.onnx https://github.com/rhasspy/piper-voices/releases/latest/download/zh_CN-huayan-medium.onnx \
 && curl -fL -o zh_CN-huayan-medium.onnx.json https://github.com/rhasspy/piper-voices/releases/latest/download/zh_CN-huayan-medium.onnx.json

ENV PIPER_BIN=/opt/piper/piper
ENV PIPER_VOICE_ZH_HUAYAN_MEDIUM=/opt/piper/voices/zh/zh_CN-huayan-medium.onnx

# --- Terminal: ensure `openclaw` works interactively ---
# Some minimal images miss a correct default shell/TERM/tini. We ensure bash and a sane TERM.
RUN apt-get update \
 && apt-get install -y --no-install-recommends bash tini \
 && rm -rf /var/lib/apt/lists/*

ENV TERM=xterm-256color

# Use tini as PID1 for proper signal handling and interactive CLI behavior.
ENTRYPOINT ["/usr/bin/tini","--"]

# Default command: run OpenClaw gateway (upstream default may differ; keep minimal).
CMD ["openclaw","gateway","start"]
