# syntax=docker/dockerfile:1.7

# Base requirement: upstream comes from OpenClaw official image.
# Note: OpenClaw images are hosted on GitHub Container Registry (GHCR).
FROM ghcr.io/openclaw/openclaw:latest

# Upstream image may default to a non-root user; apt needs root.
USER root

ARG DEBIAN_FRONTEND=noninteractive

# Some minimal bases have missing/locked apt list directories under non-root layers.
RUN mkdir -p /var/lib/apt/lists/partial /var/cache/apt/archives/partial \
 && chmod -R 755 /var/lib/apt/lists /var/cache/apt

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
# We intentionally do not build from source.
# Use a dedicated venv to avoid Debian/Ubuntu PEP-668 "externally managed" pip restrictions.
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 python3-venv python3-pip \
 && rm -rf /var/lib/apt/lists/* \
 && python3 -m venv /opt/whisper-venv \
 && /opt/whisper-venv/bin/pip install --no-cache-dir --upgrade pip \
 && /opt/whisper-venv/bin/pip install --no-cache-dir --only-binary=:all: faster-whisper ctranslate2

ENV PATH="/opt/whisper-venv/bin:${PATH}"

# --- Piper TTS + Huayan (medium) zh female voice ---
# Piper releases binaries; voices hosted separately. We download into /opt/piper.
# Use the stable "latest" asset link to avoid breakage when tags/assets change.
RUN mkdir -p /opt/piper \
 && cd /opt/piper \
 && curl -fL -o piper.tar.gz https://github.com/rhasspy/piper/releases/latest/download/piper_linux_x86_64.tar.gz \
 && tar -xzf piper.tar.gz --strip-components=1 \
 && rm -f piper.tar.gz

# Huayan medium voice (Chinese female).
# Primary source: rhasspy/piper-voices (may not always publish this asset as a "latest" release)
# Fallback source: Hugging Face mirror repo.
RUN set -e; \
  mkdir -p /opt/piper/voices/zh; \
  cd /opt/piper/voices/zh; \
  (curl -fL -o zh_CN-huayan-medium.onnx https://github.com/rhasspy/piper-voices/releases/latest/download/zh_CN-huayan-medium.onnx \
   && curl -fL -o zh_CN-huayan-medium.onnx.json https://github.com/rhasspy/piper-voices/releases/latest/download/zh_CN-huayan-medium.onnx.json) \
  || (echo "rhasspy/piper-voices latest asset not found; falling back to HuggingFace"; \
      curl -fL -o zh_CN-huayan-medium.onnx https://huggingface.co/csukuangfj/vits-piper-zh_CN-huayan-medium/resolve/main/zh_CN-huayan-medium.onnx \
      && curl -fL -o zh_CN-huayan-medium.onnx.json https://huggingface.co/csukuangfj/vits-piper-zh_CN-huayan-medium/resolve/main/zh_CN-huayan-medium.onnx.json)

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
