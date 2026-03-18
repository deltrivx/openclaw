# syntax=docker/dockerfile:1
FROM ghcr.io/openclaw/openclaw:latest

USER root

ENV LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh:en \
    LC_ALL=zh_CN.UTF-8 \
    TZ=Asia/Shanghai \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium \
    PIPER_HOST=127.0.0.1 \
    PIPER_PORT=18793 \
    PIPER_MODELS_DIR=/opt/piper/models \
    PIPER_VOICE=zh_CN-huayan-medium

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl git jq locales tzdata \
    chromium ffmpeg \
    tesseract-ocr tesseract-ocr-chi-sim \
    ocrmypdf poppler-utils \
    python3 python3-venv python3-pip \
    fonts-noto-cjk fonts-noto-color-emoji \
    libsndfile1 \
 && sed -i 's/^# *zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen \
 && locale-gen zh_CN.UTF-8 \
 && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
 && echo $TZ > /etc/timezone \
 && python3 -m venv /opt/venv \
 && /opt/venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel \
 && /opt/venv/bin/pip install --no-cache-dir fastapi uvicorn piper-tts \
 && mkdir -p "$PIPER_MODELS_DIR" /root/.agents/skills \
 && curl -fsSL -o "$PIPER_MODELS_DIR/$PIPER_VOICE.onnx" \
      https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx \
 && curl -fsSL -o "$PIPER_MODELS_DIR/$PIPER_VOICE.onnx.json" \
      https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx.json \
 && rm -rf /var/lib/apt/lists/*

ENV PATH=/opt/venv/bin:$PATH

COPY docker /opt/openclaw-enhanced/docker
COPY docs/zh /opt/openclaw-zh-docs
RUN chmod +x /opt/openclaw-enhanced/docker/entrypoint.sh

ENTRYPOINT ["/opt/openclaw-enhanced/docker/entrypoint.sh"]
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
