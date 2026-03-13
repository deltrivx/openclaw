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
# Install Playwright globally.
# Note: Node does NOT automatically include global npm modules in `require()` resolution.
# We set NODE_PATH so `require('playwright')` works everywhere.
# Also pre-download Playwright's Chromium so `chromium.launch()` works out-of-the-box
# (no more "please run npx playwright install").
ENV NODE_PATH=/usr/local/lib/node_modules
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN npm i -g playwright@1.58.2 \
 && npx playwright install chromium \
 && node -p "require('playwright/package.json').version" \
 # Provide a stable browser executable path under /usr/bin for other tools/scripts.
 && CHROME_BIN="$(ls -1 /ms-playwright/chromium-*/chrome-linux/chrome 2>/dev/null | head -n 1)" \
 && test -n "$CHROME_BIN" \
 && ln -sf "$CHROME_BIN" /usr/bin/chromium \
 && ln -sf "$CHROME_BIN" /usr/bin/google-chrome

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

# --- Python ---
# Install Python and pip.
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 python3-pip \
 && rm -rf /var/lib/apt/lists/*

# faster-whisper (binary wheels only)
RUN python3 -m pip install --no-cache-dir --break-system-packages --upgrade pip \
 && python3 -m pip install --no-cache-dir --break-system-packages --only-binary=:all: faster-whisper ctranslate2

# Python Playwright (installed into system python; PyPI versioning differs from Node)
RUN python3 -m pip install --no-cache-dir --break-system-packages "playwright>=1.50,<2" \
 && python3 -c "import playwright; print('system-python-playwright ok')"

# PyYAML (for parsing YAML in Python scripts)
RUN python3 -m pip install --no-cache-dir --break-system-packages pyyaml \
 && python3 -c "import yaml; print('pyyaml ok')"

# Ensure Python Playwright uses the same browser cache we bundle for Node.
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

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
