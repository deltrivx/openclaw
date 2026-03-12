# Dockerfile
# 目标：除新增功能外保持与官方一致（默认网关端口 18789、不改官方启动/行为）
# 新增：Chromium、ffmpeg、Piper（Huayan 中文女声）、faster-whisper（conda 环境 + pip 仅二进制轮子），修复非交互 openclaw 调用
# 修复：避免 conda 安装 ctranslate2 版本缺失；改为 pip 仅二进制安装，并用 execstack -c 清除 .so 可执行栈标志

FROM ghcr.io/openclaw/openclaw:latest

LABEL org.opencontainers.image.title="deltrivx/openclaw" \
org.opencontainers.image.description="OpenClaw (official defaults) + Chromium + Piper (Huayan) + faster-whisper (conda env + pip wheels) + ffmpeg; non-interactive openclaw fixed" \
org.opencontainers.image.source="https://github.com/deltrivx/openclaw" \
maintainer="DeltrivX"

USER root

# 必要系统依赖（不改变官方其他行为）
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
chromium chromium-common chromium-driver \
fonts-wqy-zenhei fonts-wqy-microhei \
ffmpeg \
ca-certificates curl jq tini bash bzip2 \
&& rm -rf /var/lib/apt/lists/*

ENV CHROME_PATH=/usr/bin/chromium \
PUPPETEER_SKIP_DOWNLOAD=1 \
PLAYWRIGHT_BROWSERS_PATH=/usr/bin \
TZ=Asia/Shanghai

# 安装 Miniforge（conda-forge 通道）并安装 mamba 加速求解
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH
RUN set -eux; \
arch="$(uname -m)"; \
case "$arch" in \
x86_64) mf_arch="x86_64" ;; \
aarch64) mf_arch="aarch64" ;; \
*) echo "Unsupported arch: $arch"; exit 1 ;; \
esac; \
curl -fsSL -o /tmp/miniforge.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${mf_arch}.sh"; \
bash /tmp/miniforge.sh -b -p "$CONDA_DIR"; \
rm -f /tmp/miniforge.sh; \
conda config --system --add channels conda-forge; \
conda config --system --set channel_priority strict; \
conda install -y -n base -c conda-forge mamba && conda clean -afy

# 分步创建环境（Python 3.10 轮子覆盖更广）
RUN mamba create -y -n gov python=3.10 && conda clean -afy
ENV PATH=$CONDA_DIR/envs/gov/bin:$PATH

# 先用 conda 安装底层运行库（纯二进制）
RUN mamba install -y -n gov -c conda-forge openblas onnxruntime && conda clean -afy

# 再用 pip 仅二进制安装 ASR 组件（避免源码编译/缺 wheel）
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DEFAULT_TIMEOUT=240
ENV PIP_ONLY_BINARY=:all:
RUN python -V && pip -V && \
pip install --no-cache-dir --only-binary=:all: "numpy==1.26.4" && \
pip install --no-cache-dir --only-binary=:all: "ctranslate2==4.3.1" "tokenizers==0.15.1" "faster-whisper==1.0.3"

# 清除可能的可执行栈标志，避免运行时报错（需要 execstack）
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends execstack && rm -rf /var/lib/apt/lists/* && \
find "$CONDA_DIR/envs/gov" -type f -name "libctranslate2*.so*" -exec execstack -c {} + || true && \
find "$CONDA_DIR/envs/gov" -type f -name "libonnxruntime*.so*" -exec execstack -c {} + || true

# 快速校验（不影响构建）
RUN python -c "import faster_whisper, ctranslate2, tokenizers; print('asr env ok')"

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
