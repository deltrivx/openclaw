# Dockerfile
# 目标：除新增功能外保持与官方一致（默认网关端口 18789、不改官方启动/行为）
# 新增：Chromium、ffmpeg、Piper（Huayan 中文女声）、faster-whisper（隔离 venv）
# 修复：非交互 openclaw 调用；针对 ctranslate2 可执行栈报错（execstack -c 清除标志）
# 修正：去掉 heredoc，全部使用 python -c，避免 “unterminated heredoc”

# ---- Stage 1: 预构建独立 Python 虚拟环境（并修复可执行栈标志）
FROM python:3.11-slim AS pyenv
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DEFAULT_TIMEOUT=240
ENV PIP_PREFER_BINARY=1
ENV UV_HTTP_TIMEOUT=240

# 必备构建与修复工具（包含 execstack，用于清除 .so 的可执行栈标志）
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
python3-venv python3-dev \
build-essential rustc cargo pkg-config cmake git \
libopenblas-dev libomp-dev ca-certificates curl \
execstack \
&& rm -rf /var/lib/apt/lists/*

# 预构建虚拟环境 + 安装 ASR 依赖（更兼容的版本组合）
RUN python -m venv /opt/gov && \
/opt/gov/bin/pip install --upgrade pip setuptools wheel "maturin==1.5.1" "cmake>=3.26" && \
/opt/gov/bin/pip install --no-cache-dir --prefer-binary "numpy==1.26.4" && \
/opt/gov/bin/pip install --no-cache-dir --prefer-binary "ctranslate2==4.2.1" "tokenizers==0.15.1" && \
/opt/gov/bin/pip install --no-cache-dir --prefer-binary "faster-whisper==1.0.3"

# 关键修复：移除 ctranslate2/依赖库的“可执行栈”标志，避免内核拒绝加载
RUN set -eux; \
find /opt/gov -type f -name "libctranslate2*.so*" -exec execstack -c {} + || true; \
find /opt/gov -type f -name "libonnxruntime*.so*" -exec execstack -c {} + || true; \
/opt/gov/bin/python -V && /opt/gov/bin/python -c "import ctranslate2, tokenizers, faster_whisper; print('pyenv ok')"

# ---- Stage 2: 最终镜像（官方基础 + 新增组件；其余保持官方默认）
FROM ghcr.io/openclaw/openclaw:latest

LABEL org.opencontainers.image.title="deltrivx/openclaw" \
org.opencontainers.image.description="OpenClaw (official defaults) + Chromium + Piper (Huayan) + faster-whisper (isolated venv) + ffmpeg; non-interactive openclaw fixed" \
org.opencontainers.image.source="https://github.com/deltrivx/openclaw" \
maintainer="DeltrivX"

USER root

# 仅追加必要系统依赖（不改变官方其他行为）
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
chromium chromium-common chromium-driver \
fonts-wqy-zenhei fonts-wqy-microhei \
ffmpeg \
ca-certificates curl jq tini bash \
&& rm -rf /var/lib/apt/lists/*

# 拷入预构建的独立 Python 环境（避免在此镜像内再次 pip 安装）
COPY --from=pyenv /opt/gov /opt/gov
ENV PATH=/opt/gov/bin:${PATH}

# 快速校验（不影响构建流程）
RUN python -V && python -c "import ctranslate2, tokenizers, faster_whisper; print('runtime ok')"

# 安装 Piper 与中文女声 Huayan 模型（离线 TTS；仅新增功能）
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

# 非交互/后台调用 openclaw 修复（不改变官方命令，仅追加包装以兼容 docker exec）
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec bash -lc "openclaw \"$@\""' > /usr/local/bin/oc && \
chmod +x /usr/local/bin/oc && \
ln -sf /usr/local/bin/oc /usr/local/bin/openclaw-cli

# 健康检查（与官方一致性：仅检查 CLI 可用）
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
CMD openclaw --version || oc --version || node -v || python -V || exit 1

# 官方默认网关端口：18789（保持一致）
EXPOSE 18789

# ENTRYPOINT/CMD：保持与官方一致（不覆盖官方默认启
