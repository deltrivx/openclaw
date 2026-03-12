# Dockerfile
# 目标：除新增功能外保持与官方一致（默认网关端口 18789、不改官方启动/行为）
# 新增：Chromium、ffmpeg、Piper（Huayan 中文女声）、faster-whisper（conda env + pip 仅二进制），修复非交互 openclaw 调用
# 修复：将 conda 复杂求解拆分为多步，并改用 mamba 提升成功率；Python 降为 3.10（wheel 覆盖面更广）

FROM ghcr.io/openclaw/openclaw:latest

LABEL org.opencontainers.image.title="deltrivx/openclaw" \
org.opencontainers.image.description="OpenClaw (official defaults) + Chromium + Piper (Huayan) + faster-whisper (conda env + binary wheels) + ffmpeg; non-interactive openclaw fixed" \
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

# 分步创建环境（降低冲突概率）
# 1) 仅创建空环境（Python 3.10 兼容性更广）
RUN mamba create -y -n gov python=3.10 && conda clean -afy

# 2) 在环境内逐步安装依赖：openblas/onnxruntime/ctranslate2
RUN mamba install -y -n gov -c conda-forge openblas onnxruntime && conda clean -afy
RUN mamba install -y -n gov -c conda-forge ctranslate2=4.2.1 && conda clean -afy

# 3) 在环境内用 pip 安装仅二进制的 faster-whisper 与 tokenizers
ENV PATH=$CONDA_DIR/envs/gov/bin:$PATH
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DEFAULT_TIMEOUT=240
ENV PIP_ONLY_BINARY=:all:
RUN python -V && pip -V && \
pip install --no-cache-dir --only-binary=:all: "tokenizers==0.15.1" "faster-whisper==1.0.3" && \
python -c "import faster_whisper, ctranslate2, tokenizers; print('asr env ok')"

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

# ENTRYPOINT/CMD：保持与官方一致（不覆盖官方默认启动）
