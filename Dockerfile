# syntax=docker/dockerfile:1
# OpenClaw (Docker image) + Chinese translation (nightly)
# Base image: upstream OpenClaw

FROM ghcr.io/openclaw/openclaw:latest

USER root

# Locale / timezone
ENV LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh:en \
    LC_ALL=zh_CN.UTF-8 \
    TZ=Asia/Shanghai

# Playwright: use system Chromium; never download browsers at runtime
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium

# System packages
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl git jq \
    locales tzdata \
    fonts-noto-cjk fonts-noto-color-emoji \
    chromium \
    ffmpeg \
    tesseract-ocr tesseract-ocr-chi-sim \
    ocrmypdf \
    poppler-utils \
    python3-venv \
    libsndfile1 \
    # common Chromium/Playwright deps
    libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libdrm2 libgbm1 libgtk-3-0 \
    libnss3 libx11-xcb1 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libxshmfence1 \
    libxkbcommon0 libpango-1.0-0 libpangocairo-1.0-0 libxext6 libxss1 libxtst6 \
 && sed -i 's/^# *zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen \
 && locale-gen zh_CN.UTF-8 \
 && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
 && echo $TZ > /etc/timezone \
 && rm -rf /var/lib/apt/lists/*

# Python venv for optional runtime helpers (Piper)
RUN python3 -m venv /opt/venv \
 && /opt/venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel
ENV PATH=/opt/venv/bin:$PATH

# Piper TTS runtime deps
RUN /opt/venv/bin/pip install --no-cache-dir \
    fastapi uvicorn loguru pyyaml langdetect piper-tts

# Piper voice model: zh_CN-huayan-medium (can be overridden)
ENV PIPER_MODELS_DIR=/opt/piper/models \
    PIPER_VOICE=zh_CN-huayan-medium
RUN mkdir -p "$PIPER_MODELS_DIR" \
 && curl -fsSL -o "$PIPER_MODELS_DIR/$PIPER_VOICE.onnx" \
    https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx \
 && curl -fsSL -o "$PIPER_MODELS_DIR/$PIPER_VOICE.onnx.json" \
    https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx.json

# --- Chinese translation (nightly) ---
# Reference: https://github.com/1186258278/OpenClawChineseTranslation/releases/tag/nightly
# Install the translated distribution as a global CLI.
# We intentionally do NOT patch /app/dist bundles to keep compatibility with upstream updates.
# Install into an isolated prefix to avoid clobbering the upstream /usr/local/bin/openclaw
# (upstream image already provides an openclaw binary)
RUN npm install --omit=dev --prefix /opt/openclaw-zh @qingchencloud/openclaw-zh@nightly \
 && node -e "console.log('openclaw-zh version:', require('/opt/openclaw-zh/node_modules/@qingchencloud/openclaw-zh/package.json').version)"
 \
 && (PKG=/opt/openclaw-zh/node_modules/@qingchencloud/openclaw-zh; \
     if [ ! -e "$PKG/dist/extensions" ] && [ -d "$PKG/extensions" ]; then \
       mkdir -p "$PKG/dist"; \
       ln -sf ../extensions "$PKG/dist/extensions"; \
     fi)

# Skills default dir
RUN mkdir -p /root/.agents/skills

# Entrypoint wrapper: start Piper server then OpenClaw
COPY openai_tts_server.py /usr/local/bin/openai_tts_server.py
COPY piper-entrypoint.sh /usr/local/bin/piper-entrypoint.sh
RUN chmod +x /usr/local/bin/openai_tts_server.py /usr/local/bin/piper-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/piper-entrypoint.sh"]

EXPOSE 18789
# Piper API (internal). Not published by default.
EXPOSE 18793

# Use the Chinese translated OpenClaw CLI as the main command
CMD ["node", "/opt/openclaw-zh/node_modules/@qingchencloud/openclaw-zh/openclaw.mjs", "gateway", "--allow-unconfigured"]
