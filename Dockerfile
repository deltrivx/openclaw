FROM ghcr.io/openclaw/openclaw:latest

LABEL org.opencontainers.image.title="deltrivx/openclaw" \
      org.opencontainers.image.description="OpenClaw + Chromium + Piper (Huayan medium) + faster-whisper + ffmpeg; auto-update capable; openclaw CLI fixed for detached containers" \
      org.opencontainers.image.source="https://github.com/deltrivx/openclaw" \
      maintainer="DeltrivX"

USER root

# 核心系统依赖：Chromium/ffmpeg/Python/构建链（Rust+GCC）
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    chromium \
    chromium-common \
    chromium-driver \
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    ffmpeg \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    rustc \
    cargo \
    pkg-config \
    ca-certificates \
    curl \
    jq \
    tini \
 && rm -rf /var/lib/apt/lists/*

# 环境变量：浏览器、pip缓存、网络超时等
ENV CHROME_PATH=/usr/bin/chromium \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    PLAYWRIGHT_BROWSERS_PATH=/usr/bin \
    PIP_NO_CACHE_DIR=1 \
    UV_HTTP_TIMEOUT=120

# Python 依赖安装顺序：先 numpy<2，再 ctranslate2、tokenizers，最后 faster-whisper
# 这样在 amd64/arm64 下即使无预编译轮子也能本地编译通过（rustc/cargo 已安装）
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir "numpy<2" && \
    pip3 install --no-cache-dir "ctranslate2==4.3.1" "tokenizers==0.15.2" && \
    pip3 install --no-cache-dir "faster-whisper==1.0.3"

# 安装 Piper 与中文女声「Huayan medium」模型（离线 TTS）
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
    curl -fsSL -o /opt/piper/models/zh-CN-huayan-medium.onnx "https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/zh-CN-huayan-medium.onnx" && \
    curl -fsSL -o /opt/piper/models/zh-CN-huayan-medium.onnx.json "https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/zh-CN-huayan-medium.onnx.json"

# 内联 entrypoint：修复非交互 exec 与可选上游自动更新
RUN printf '%s\n' \
'#!/usr/bin/env bash' \
'set -euo pipefail' \
': "${OPENCLAW_AUTO_UPDATE:=true}"' \
': "${OPENCLAW_UPDATE_CHANNEL:=stable}"' \
'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"' \
'# 若 openclaw 不在 PATH，尝试用 npx 软链（兼容某些上游镜像布局）' \
'if ! command -v openclaw >/dev/null 2>&1; then' \
'  if command -v npx >/dev/null 2>&1; then' \
'    ln -sf "$(command -v npx)" /usr/local/bin/openclaw || true' \
'  fi' \
'fi' \
'if [[ "${OPENCLAW_AUTO_UPDATE}" == "true" ]]; then' \
'  echo "[entrypoint] Auto-updating OpenClaw (channel=${OPENCLAW_UPDATE_CHANNEL})..."' \
'  command -v openclaw >/dev/null 2>&1 && openclaw gateway update || true' \
'fi' \
'node -v || true' \
'npm -v || true' \
'openclaw --version || true' \
'if [[ $# -gt 0 ]]; then exec "$@"; fi' \
'exec openclaw gateway start' \
> /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

# oc/openclaw-cli 包装：保证 docker exec 非交互场景可直接调用 openclaw
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec bash -lc "openclaw \"$@\""' > /usr/local/bin/oc && \
    chmod +x /usr/local/bin/oc && \
    ln -sf /usr/local/bin/oc /usr/local/bin/openclaw-cli

# 运行时开关
ENV OPENCLAW_AUTO_UPDATE=true \
    OPENCLAW_UPDATE_CHANNEL=stable

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
  CMD openclaw --version || oc --version || node -v || exit 1

# 常用端口（按需调整）
EXPOSE 3000 8080

# PID1：tini，确保信号转发与僵尸清理
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]

# 默认启动网关
CMD ["openclaw", "gateway", "start"]
