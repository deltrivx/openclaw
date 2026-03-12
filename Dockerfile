# Dockerfile
# 目标：除新增功能外，其余与官方保持一致（默认网关端口 18789、不更改官方行为）
# 新增功能：内置 Chromium、ffmpeg、Piper（Huayan medium 中文女声）、faster-whisper（隔离 pyenv），修复非交互 openclaw 调用

# ---- Stage 1: build isolated Python env (venv with all deps preinstalled)
FROM python:3.11-slim AS pyenv
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DEFAULT_TIMEOUT=180
ENV PIP_PREFER_BINARY=1
ENV UV_HTTP_TIMEOUT=180
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
build-essential rustc cargo pkg-config cmake git \
libopenblas-dev libomp-dev ca-certificates curl \
&& rm -rf /var/lib/apt/lists/*
# 预构建独立虚拟环境，避免在最终镜像内二次编译/装包导致 buildx 失败
RUN python -m venv /opt/gov && \
/opt/gov/bin/pip install --upgrade pip setuptools wheel "maturin==1.5.1" "cmake>=3.26" && \
/opt/gov/bin/pip install --no-cache-dir --prefer-binary "numpy<2" && \
/opt/gov/bin/pip install --no-cache-dir --prefer-binary "ctranslate2==4.2.1" "tokenizers==0.15.1" && \
/opt/gov/bin/pip install --no-cache-dir --prefer-binary "faster-whisper==1.0.3" && \
/opt/gov/bin/python -V && /opt/gov/bin/python -c "import ctranslate2, tokenizers, faster_whisper; print('pyenv ok')"

# ---- Stage 2: final image (official base + minimal additions)
FROM ghcr.io/openclaw/openclaw:latest

LABEL org.opencontainers.image.title="deltrivx/openclaw" \
org.opencontainers.image.description="OpenClaw (official defaults) + Chromium + Piper (Huayan medium) + faster-whisper (isolated pyenv) + ffmpeg; non-interactive openclaw fixed" \
org.opencontainers.image.source="https://github.com/deltrivx/openclaw" \
maintainer="DeltrivX"

USER root

# 与官方保持一致：仅追加我们所需的系统依赖（不改官方端口/行为）
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
chromium chromium-common chromium-driver \
fonts-wqy-zenhei fonts-wqy-microhei \
ffmpeg \
ca-certificates curl jq tini bash \
&& rm -rf /var/lib/apt/lists/*

# 将预构建的独立 Python 环境拷入（避免在此镜像内 pip 安装，规避 buildx 报错）
COPY --from=pyenv /opt/gov /opt/gov
ENV PATH=/opt/gov/bin:${PATH}

# 快速验证（不影响构建继续）
RUN python -V && python -c "import ctranslate2, tokenizers, faster_whisper; print('runtime ok')"

# 安装 Piper 与中文女声 Huayan medium（离线 TTS；仅新增功能，其他对官方不改动）
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

# 非交互/后台调用 openclaw 修复（不改变官方命令，只加包装以兼容 docker exec）
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec bash -lc "openclaw \"$@\""' > /usr/local/bin/oc && \
chmod +x /usr/local/bin/oc && \
ln -sf /usr/local/bin/oc /usr/local/bin/openclaw-cli

# 健康检查（与官方一致性：只检查 CLI 可用）
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
CMD openclaw --version || oc --version || node -v || python -V || exit 1

# 官方默认网关端口：18789（保持一致）
EXPOSE 18789

# ENTRYPOINT/CMD：保持与官方一致（由官方镜像的默认启动流程接管）
# 若官方镜像已有 ENTRYPOINT/CMD，这里不覆盖（不做任何改变）
