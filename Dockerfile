# syntax=docker/dockerfile:1.7

# Enhanced runtime image based on upstream OpenClaw.
# Goal: Docker-friendly, batteries-included (chromium+playwright, ffmpeg, OCR, piper TTS, venv python tools)

FROM ghcr.io/openclaw/openclaw:latest

# Upstream image defaults to non-root (node). Package installs require root.
USER root

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

# ---- Environment defaults ----
# Skills/agents
ENV OPENCLAW_AGENT_DIR=/root/.agents \
    CLAWHUB_WORKDIR=/root/.agents \
    OPENCLAW_SKILLS_DIR=/root/.agents/skills \
    # Python venv
    VENV_PATH=/opt/venv \
    PATH=/opt/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    # Browser
    CHROME_PATH=/usr/bin/chromium

# ---- System packages ----
# chromium + deps, fonts (CJK), multimedia, OCR/PDF utilities, python3 + venv
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl wget unzip xz-utils \
      chromium \
      # Chromium runtime deps (keep explicit for stability across base updates)
      libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libdrm2 libgbm1 libnspr4 libnss3 \
      libx11-xcb1 libxcomposite1 libxdamage1 libxfixes3 libxkbcommon0 libxrandr2 \
      libpango-1.0-0 libcairo2 libpangocairo-1.0-0 \
      fonts-noto-cjk fonts-noto-color-emoji \
      ffmpeg \
      tesseract-ocr tesseract-ocr-chi-sim \
      ocrmypdf poppler-utils \
      python3 python3-venv \
 && rm -rf /var/lib/apt/lists/*

# ---- Python venv ----
# Keep system python at /usr/bin/python3, but prefer venv via PATH.
RUN python3 -m venv "$VENV_PATH" \
 && "$VENV_PATH/bin/pip" install --no-cache-dir --upgrade pip setuptools wheel \
 && "$VENV_PATH/bin/pip" install --no-cache-dir edge-tts

# ---- Piper (offline TTS) + voice model baked in ----
# Piper binary (x86_64) from rhasspy/piper release.
ARG PIPER_VERSION=2023.11.14-2
RUN mkdir -p /opt/piper/bin \
 && curl -fsSL -o /tmp/piper.tar.gz "https://github.com/rhasspy/piper/releases/download/${PIPER_VERSION}/piper_linux_x86_64.tar.gz" \
 && tar -xzf /tmp/piper.tar.gz -C /opt/piper/bin --strip-components=1 \
 && rm -f /tmp/piper.tar.gz \
 && ln -sf /opt/piper/bin/piper /usr/local/bin/piper

# Huayan medium model from the canonical voices repo.
# Reference: https://huggingface.co/rhasspy/piper-voices (voices.json)
ARG PIPER_VOICE_BASE_URL=https://huggingface.co/rhasspy/piper-voices/resolve/main
RUN mkdir -p /opt/piper/models \
 && curl -fsSL -o /opt/piper/models/zh_CN-huayan-medium.onnx \
      "$PIPER_VOICE_BASE_URL/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx" \
 && curl -fsSL -o /opt/piper/models/zh_CN-huayan-medium.onnx.json \
      "$PIPER_VOICE_BASE_URL/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx.json"

# Simple offline TTS wrapper: text -> wav
RUN cat > /usr/local/bin/piper-tts <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   echo "你好" | piper-tts /tmp/out.wav
#   piper-tts /tmp/out.wav <<<"你好"

OUT_PATH="${1:-}"
if [[ -z "${OUT_PATH}" ]]; then
  echo "usage: piper-tts <out.wav>" >&2
  exit 2
fi

MODEL="/opt/piper/models/zh_CN-huayan-medium.onnx"
CONFIG="/opt/piper/models/zh_CN-huayan-medium.onnx.json"

/usr/local/bin/piper \
  --model "$MODEL" \
  --config "$CONFIG" \
  --output_file "$OUT_PATH"
EOF
RUN chmod +x /usr/local/bin/piper-tts

# ---- OpenClaw Gateway in Docker: run foreground by default ----
# (Service-based start is often unavailable in containers.)
EXPOSE 19000

# Runtime as root (requested for Unraid volume mappings using /root/.openclaw).
# Default to foreground gateway.
CMD ["openclaw", "gateway", "run", "--allow-unconfigured"]
