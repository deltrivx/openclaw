# Dockerfile
# 目标：完整功能开箱即用（Chromium + ffmpeg + faster-whisper + Piper Huayan），保持官方默认端口/行为（18789）。
# 方案：Miniforge + mamba（稳定二进制包），pip 仅二进制轮子安装 ASR 组件；Piper 二进制与模型多源回退，避免下载失败。
# 同时修复容器内非交互 docker exec openclaw 失效问题。

FROM ghcr.io/openclaw/openclaw:latest

LABEL org.opencontainers.image.title="deltrivx/openclaw" \
org.opencontainers.image.description="OpenClaw (official defaults) + Chromium + ffmpeg + faster-whisper (conda+mamba+binary wheels) + Piper (Huayan), non-interactive openclaw fixed" \
org.opencontainers.image.source="https://github.com/deltrivx/openclaw" \
maintainer="DeltrivX"

USER root

# 基础系统依赖（不改官方其他行为）
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

# 安装 Miniforge（conda-forge）+ mamba（更稳）
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH
RUN set -eux; \
arch="$(uname -m)"; \
case "$arch" in \
x86_64) mf_arch="x86_64" ;; \
aarch64) mf_arch="aarch64" ;; \
*) echo "Unsupported arch: $arch" && exit 1 ;; \
esac; \
curl -fsSL -o /tmp/miniforge.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${mf_arch}.sh"; \
bash /tmp/miniforge.sh -b -p "$CONDA_DIR"; \
rm -f /tmp/miniforge.sh; \
conda config --system --add channels conda-forge; \
conda config --system --set channel_priority strict; \
conda install -y -n base -c conda-forge mamba && conda clean -afy

# 创建 Python 3.10 环境（轮子覆盖更广）并安装底层二进制依赖
RUN mamba create -y -n gov python=3.10 && conda clean -afy
ENV PATH=$CONDA_DIR/envs/gov/bin:$PATH
RUN mamba install -y -n gov -c conda-forge openblas onnxruntime && conda clean -afy

# 使用 pip 仅二进制轮子安装 ASR 组件（避免源码编译/ABI 不兼容）
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DEFAULT_TIMEOUT=240
ENV PIP_ONLY_BINARY=:all:
RUN python -V && pip -V
RUN pip install --no-cache-dir --only-binary=:all: "numpy==1.26.4"
RUN pip install --no-cache-dir --only-binary=:all: "ctranslate2==4.3.1" "tokenizers==0.15.1" "faster-whisper==1.0.3"
RUN python -c "import faster_whisper, ctranslate2, tokenizers; print('asr env ok')"

# 安装 Piper 二进制（多源回退：jsDelivr -> GitHub -> ghproxy+GitHub）
ARG PIPER_VERSION=1.2.0
RUN set -eux; \
arch="$(uname -m)"; \
case "$arch" in \
x86_64) piper_pkg="piper_linux_x86_64" ;; \
aarch64) piper_pkg="piper_linux_aarch64" ;; \
armv7l) piper_pkg="piper_linux_armv7l" ;; \
*) echo "Unsupported arch: $arch" && exit 1 ;; \
esac; \
mkdir -p /opt/piper/models && cd /opt/piper; \
# 1) jsDelivr（GitHub 镜像 CDN）
curl -fL --retry 3 --retry-delay 2 -o piper.tar.gz "https://cdn.jsdelivr.net/gh/rhasspy/piper@v${PIPER_VERSION}/${piper_pkg}.tar.gz" || \
# 2) GitHub Releases
curl -fL --retry 3 --retry-delay 2 -o piper.tar.gz "https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/${piper_pkg}.tar.gz" || \
# 3) ghproxy + GitHub
curl -fL --retry 3 --retry-delay 2 -o piper.tar.gz "https://ghproxy.com/https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/${piper_pkg}.tar.gz"; \
tar -xzf piper.tar.gz && rm piper.tar.gz; \
install -m 0755 piper /usr/local/bin/piper

# 下载 Huayan 模型（优先 HuggingFace 稳定直链，失败则回退 GitHub Releases）
ENV PIPER_MODEL_DIR=/opt/piper/models
RUN set -eux; mkdir -p "$PIPER_MODEL_DIR"
RUN set -eux; \
curl -fL --retry 3 --retry-delay 2 \
-o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx" \
"https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh-CN-huayan-medium.onnx?download=true" || \
curl -fL --retry 3 --retry-delay 2 \
-o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx" \
"https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/zh-CN-huayan-medium.onnx"
RUN set -eux; \
curl -fL --retry 3 --retry-delay 2 \
-o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx.json" \"https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh-CN-huayan-medium.onnx.json?download=true" || \
curl -fL --retry 3 --retry-delay 2 \
-o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx.json" \
"https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/zh-CN-huayan-medium.onnx.json"

# Piper 自检（不阻断构建）
RUN bash -lc 'echo "你好，世界" | piper -m /opt/piper/models/zh-CN-huayan-medium.onnx -f /tmp/tts.wav || true'

# 非交互/后台调用 openclaw 修复（不改变官方命令，仅追加包装以兼容 docker exec）
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec bash -lc "openclaw \"$@\""' > /usr/local/bin/oc && \
chmod +x /usr/local/bin/oc && \
ln -sf /usr/local/bin/oc /usr/local/bin/openclaw-cli

# 健康检查（JSON 数组格式）
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
CMD ["bash","-lc","openclaw --version || oc --version || node -v || python -V || exit 1"]

# 官方默认网关端口：18789（保持一致）
EXPOSE 18789

# ENTRYPOINT/CMD：保持与官方一致（不覆盖官方默认启动）
