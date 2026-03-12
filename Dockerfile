# 多阶段构建（最稳）：在独立 Python 构建环境先打 wheels，再拷入 OpenClaw 基镜像安装
# 规避 buildx 下 pip 源码编译不稳定/网络抖动问题，提升成功率

# ---- Stage 1: build Python wheels
FROM python:3.11-slim AS wheels
ENV PIP_NO_CACHE_DIR=1 \
PIP_DEFAULT_TIMEOUT=180 \
PIP_PREFER_BINARY=1 \
UV_HTTP_TIMEOUT=180
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
build-essential rustc cargo pkg-config cmake git \
libopenblas-dev libomp-dev curl ca-certificates \
&& rm -rf /var/lib/apt/lists/*
RUN python -V && pip -V
RUN mkdir -p /wheels
# 锁定更兼容的版本组合，优先 manylinux 轮子（失败才会源码编译）
RUN pip wheel --no-cache-dir --wheel-dir /wheels "numpy<2"
RUN pip wheel --no-cache-dir --wheel-dir /wheels "ctranslate2==4.2.1" "tokenizers==0.15.1"
RUN pip wheel --no-cache-dir --wheel-dir /wheels "faster-whisper==1.0.3"
# 可选：列出 wheels 以便诊断
RUN ls -lh /wheels

# ---- Stage 2: final image
FROM ghcr.io/openclaw/openclaw:latest

LABEL org.opencontainers.image.title="deltrivx/openclaw" \
org.opencontainers.image.description="OpenClaw + Chromium + Piper (Huayan medium) + faster-whisper + ffmpeg; wheels-based install; auto-update; non-interactive openclaw fixed" \
org.opencontainers.image.source="https://github.com/deltrivx/openclaw" \
maintainer="DeltrivX"

USER root

# 系统依赖：Chromium/ffmpeg/Python/pip
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
chromium chromium-common chromium-driver \
fonts-wqy-zenhei fonts-wqy-microhei \
ffmpeg \
python3 python3-pip python3-venv python3-dev \
ca-certificates curl jq tini bash \
&& rm -rf /var/lib/apt/lists/*

ENV CHROME_PATH=/usr/bin/chromium \
PUPPETEER_SKIP_DOWNLOAD=1 \
PLAYWRIGHT_BROWSERS_PATH=/usr/bin \
PIP_NO_CACHE_DIR=1 \
PIP_DEFAULT_TIMEOUT=180 \
PIP_PREFER_BINARY=1 \
UV_HTTP_TIMEOUT=180 \
TZ=Asia/Shanghai

# 拷入预构建 wheels 并离线安装（避免在基镜像内再拉网/编译）
COPY --from=wheels /wheels /wheels
RUN python3 -V && pip3 -V && pip3 install --no-cache-dir /wheels/*

# 安装 Piper 与中文女声 Huayan medium（离线 TTS）
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
install -m 0755 piper /usr/local/bin/piper && \
curl -fsSL -o /opt/piper/models/zh-CN-huayan-medium.onnx "https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/zh-CN-huayan-medium.onnx" && \
curl -fsSL -o /opt/piper/models/zh-CN-huayan-medium.onnx.json "https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/zh-CN-huayan-medium.onnx.json"

# 入口脚本：修复非交互 docker exec openclaw；支持开机自更新
RUN printf '%s\n' \
'#!/usr/bin/env bash' \
'set -euo pipefail' \
': "${OPENCLAW_AUTO_UPDATE:=true}"' \
': "${OPENCLAW_UPDATE_CHANNEL:=stable}"' \
'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"' \
'if ! command -v openclaw >/dev/null 2>&1; then' \
' if command -v npx >/dev/null 2>&1; then' \
' ln -sf "$(command -v npx)" /usr/local/bin/openclaw || true' \
' fi' \
'fi' \
'if [[ "${OPENCLAW_AUTO_UPDATE}" == "true" ]]; then' \
' echo "[entrypoint] Auto-updating OpenClaw (channel=${OPENCLAW_UPDATE_CHANNEL})..."' \
' command -v openclaw >/dev/null 2>&1 && openclaw gateway update || true' \
'fi' \
'node -v || true' \
'npm -v || true' \
'openclaw --version || true' \
'python3 -V || true' \
'if [[ $# -gt 0 ]]; then exec "$@"; fi' \
'exec openclaw gateway start' \
> /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

# oc/openclaw-cli 包装：保证非交互/后台可直接 openclaw
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec bash -lc "openclaw \"$@\""' > /usr/local/bin/oc && \
chmod +x /usr/local/bin/oc && \
ln -sf /usr/local/bin/oc /usr/local/bin/openclaw-cli

# 运行时开关ENV OPENCLAW_AUTO_UPDATE=true \
OPENCLAW_UPDATE_CHANNEL=stable

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
CMD openclaw --version || oc --version || node -v || python3 -V || exit 1

# 常用端口（按需）
EXPOSE 3000 8080

# PID1：tini
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["openclaw", "gateway", "start"]
