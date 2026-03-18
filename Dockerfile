# syntax=docker/dockerfile:1
# Enhanced OpenClaw image (Docker-ready)
# Base: upstream OpenClaw image

FROM ghcr.io/openclaw/openclaw:latest

# --- rebuild marker (no functional change) ---
# rebuild: 2026-03-17T19:59Z



# Localization (Chinese + timezone)
ENV LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh:en \
    LC_ALL=zh_CN.UTF-8 \
    TZ=Asia/Shanghai
USER root

# Playwright: use system Chromium; never download browsers at runtime
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium

# System packages
# - chromium: browser automation
# - ffmpeg: media
# - tesseract-ocr + chi_sim: OCR (Chinese)
# - ocrmypdf: scanned PDF -> searchable
# - poppler-utils: pdftotext, pdfinfo, etc.
# - jq: JSON tooling
# - Common Chromium/Playwright deps
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl git npm \
    locales tzdata \
    fonts-noto-cjk fonts-noto-color-emoji \
    chromium \
    ffmpeg \
    tesseract-ocr tesseract-ocr-chi-sim \
    ocrmypdf \
    poppler-utils \
    jq \
    python3-venv \
    build-essential python3-dev pkg-config libffi-dev libssl-dev rustc cargo \
    # audio deps (Piper)
    libsndfile1 \
    # common Chromium/Playwright deps
    libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libdrm2 libgbm1 libgtk-3-0 \
    libnss3 libx11-xcb1 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libxshmfence1 \
    libxkbcommon0 libpango-1.0-0 libpangocairo-1.0-0 libxext6 libxss1 libxtst6 \
\
 && sed -i 's/^# *zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen \
 && locale-gen zh_CN.UTF-8 \
 && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
 && echo $TZ > /etc/timezone && rm -rf /var/lib/apt/lists/*


# --- Build-time Chinese i18n patch (rule-based; never touches /root/.openclaw) ---
COPY translations/ /opt/openclaw-zh/translations/
COPY scripts/apply_translations.py /opt/openclaw-zh/apply_translations.py
COPY scripts/repair_i18n_identifiers.py /opt/openclaw-zh/repair_i18n_identifiers.py
COPY scripts/patch_entry_exports.py /opt/openclaw-zh/patch_entry_exports.py
COPY scripts/patch_node24_shim.py /opt/openclaw-zh/patch_node24_shim.py

# 1) apply translations safely (JS/TS strings only)
RUN /bin/bash -lc 'chmod +x /opt/openclaw-zh/apply_translations.py && python3 /opt/openclaw-zh/apply_translations.py --rules /opt/openclaw-zh/translations --root /app --root /usr/local --root /usr/lib --report /var/log/zh-report.json'

# 2) node24 shim (guard missing ensureSupportedNodeVersion)
RUN /bin/bash -lc 'chmod +x /opt/openclaw-zh/patch_node24_shim.py && python3 /opt/openclaw-zh/patch_node24_shim.py'

# 3) repair any prior identifier corruption in /app bundles
RUN /bin/bash -lc 'chmod +x /opt/openclaw-zh/repair_i18n_identifiers.py && python3 /opt/openclaw-zh/repair_i18n_identifiers.py'

# 4) NOTE: patch_entry_exports disabled.
# Reason: upstream entry bundle already defines many bindings (e.g. parseCliProfileArgs).
# Our injection-based patch can mis-detect and create duplicate declarations under Node 24:
#   SyntaxError: Identifier 'parseCliProfileArgs' has already been declared
# If upstream reintroduces "Export '<name>' is not defined in module" on Node 24,
# we should rework patch_entry_exports.py to be strictly idempotent and ultra-conservative.

# Python venv convention: keep system python3; provide /opt/venv and prefer it in PATH
RUN python3 -m venv /opt/venv \
 && /opt/venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel
ENV PATH=/opt/venv/bin:$PATH

# bun (latest)
RUN curl -fsSL https://bun.sh/install | bash \
 && ln -sf /root/.bun/bin/bun /usr/local/bin/bun \
 && ln -sf /root/.bun/bin/bunx /usr/local/bin/bunx

# ClawHub CLI (latest)
# Install via bun to avoid relying on npm being present in base image
RUN bun add -g clawhub \
 && ln -sf /root/.bun/bin/clawhub /usr/local/bin/clawhub

# Piper TTS runtime deps (we run piper directly; OpenAI-compatible wrapper optional)
RUN /opt/venv/bin/pip install --no-cache-dir \
    fastapi uvicorn loguru pyyaml langdetect piper-tts

# Piper voice model: zh_CN-huayan-medium
ENV PIPER_MODELS_DIR=/opt/piper/models \
    PIPER_VOICE=zh_CN-huayan-medium
RUN mkdir -p "$PIPER_MODELS_DIR" \
 && curl -fsSL -o "$PIPER_MODELS_DIR/$PIPER_VOICE.onnx" \
    https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx \
 && curl -fsSL -o "$PIPER_MODELS_DIR/$PIPER_VOICE.onnx.json" \
    https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx.json

# Skills default dir
RUN mkdir -p /root/.agents/skills

# Entry point wrapper: start Piper server then OpenClaw
COPY openai_tts_server.py /usr/local/bin/openai_tts_server.py
COPY piper-entrypoint.sh /usr/local/bin/piper-entrypoint.sh
RUN chmod +x /usr/local/bin/openai_tts_server.py /usr/local/bin/piper-entrypoint.sh

# Ensure container runs as root
USER root

ENTRYPOINT ["/usr/local/bin/piper-entrypoint.sh"]

EXPOSE 18789
# Piper API (internal). Not published by default.
EXPOSE 18793

# Preserve upstream command
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]