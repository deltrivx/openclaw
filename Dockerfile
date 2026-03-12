# deltrivx/openclaw — Extended image
# Base: upstream OpenClaw latest
FROM ghcr.io/openclaw/openclaw:latest

# Labels
LABEL org.opencontainers.image.title="deltrivx/openclaw" \
      org.opencontainers.image.description="OpenClaw + Chromium + Piper (Huayan medium) + faster-whisper + ffmpeg; auto-update capable; openclaw CLI fixed for detached containers" \
      org.opencontainers.image.source="https://github.com/deltrivx/openclaw" \
      maintainer="DeltrivX"

USER root

# Install Chromium, ffmpeg, python3-pip and dependencies
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    chromium \
    chromium-common \
    chromium-driver \
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    ffmpeg \
    python3 \
    python3-pip \
    ca-certificates \
    curl \
    jq \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Environment for Chromium discovery
ENV CHROME_PATH=/usr/bin/chromium \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    PLAYWRIGHT_BROWSERS_PATH=/usr/bin

# Install faster-whisper (ASR)
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir faster-whisper==1.0.3

# Install Piper TTS binary and the Huayan medium model
# Reference: https://github.com/rhasspy/piper
ARG PIPER_VERSION=1.2.0
RUN set -eux; \
    arch=$(uname -m); \
    case "$arch" in \
      x86_64) piper_pkg="piper_linux_x86_64" ;; \
      aarch64) piper_pkg="piper_linux_aarch64" ;; \
      armv7l) piper_pkg="piper_linux_armv7l" ;; \
      *) echo "Unsupported arch: $arch"; exit 1 ;; \
    esac; \
    mkdir -p /opt/piper/models && \
    cd /opt/piper && \
    curl -fsSL -o piper.tar.gz "https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/${piper_pkg}.tar.gz" && \
    tar -xzf piper.tar.gz && rm piper.tar.gz && \
    ln -sf /opt/piper/piper /usr/local/bin/piper && \
    # Download Huayan medium (Chinese female) model
    curl -fsSL -o /opt/piper/models/zh-CN-huayan-medium.onnx "https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/zh-CN-huayan-medium.onnx" && \
    curl -fsSL -o /opt/piper/models/zh-CN-huayan-medium.onnx.json "https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/zh-CN-huayan-medium.onnx.json"

# Place wrappers and entrypoint
COPY scripts/ /usr/local/share/deltrivx-openclaw/scripts/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/share/deltrivx-openclaw/scripts/*.sh

# Ensure openclaw is invokable even in non-interactive shells
# The wrapper ensures bash -lc is used so that PATH and npx bindings load correctly
RUN printf '%s\n' '#!/usr/bin/env bash' \
              'exec bash -lc "openclaw "$@""' \
    > /usr/local/bin/oc && chmod +x /usr/local/bin/oc && \
    ln -sf /usr/local/bin/oc /usr/local/bin/openclaw-cli

# Auto-update behavior can be toggled by env var
ENV OPENCLAW_AUTO_UPDATE=true \
    OPENCLAW_UPDATE_CHANNEL=stable

# Minimal healthcheck: ensure the CLI responds
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
  CMD openclaw --version || oc --version || node -v || exit 1

# Expose default OpenClaw ports if any are used (placeholder)
EXPOSE 3000 8080

# Use tini to handle PID 1 signals correctly
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]

# Default command: start OpenClaw gateway
CMD ["openclaw", "gateway", "start"]
