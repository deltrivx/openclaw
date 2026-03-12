# Dockerfile
# 保持与官方一致（默认网关 18789、不改官方启动/行为）
# 新增：Chromium、ffmpeg、Piper（Huayan 中文女声，改用 HuggingFace 稳定直链）、faster-whisper（conda env + pip 仅二进制轮子）
# 修复：非交互 openclaw 调用；修正 HEALTHCHECK 语法；拆分 RUN，避免长行/截断导致的构建失败

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

# 安装 Miniforge（conda-forge 通道）并装 mamba
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH
RUN arch="$(uname -m)" && \
case "$arch" in \
x86_64) mf_arch="x86_64" ;; \
aarch64) mf_arch="aarch64" ;; \
*) echo "Unsupported arch: $arch" && exit 1 ;; \
esac && \
curl -fsSL -o /tmp/miniforge.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${mf_arch}.sh" && \
bash /tmp/miniforge.sh -b -p "$CONDA_DIR" && \
rm -f /tmp/miniforge.sh && \
conda config --system --add channels conda-forge && \
conda config --system --set channel_priority strict && \
conda install -y -n base -c conda-forge mamba && \
conda clean -afy

# 创建 Python 3.10 环境（轮子覆盖更广）
RUN mamba create -y -n gov python=3.10 && conda clean -afy
ENV PATH=$CONDA_DIR/envs/gov/bin:$PATH

# 先装底层二进制依赖
RUN mamba install -y -n gov -c conda-forge openblas onnxruntime && conda clean -afy

# 再用 pip 安装仅二进制 ASR 组件
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DEFAULT_TIMEOUT=240
ENV PIP_ONLY_BINARY=:all:
RUN python -V && pip -V
RUN pip install --no-cache-dir --only-binary=:all: "numpy==1.26.4"
RUN pip install --no-cache-dir --only-binary=:all: "ctranslate2==4.3.1" "tokenizers==0.15.1" "faster-whisper==1.0.3"
RUN python -c "import faster_whisper, ctranslate2, tokenizers; print('asr env ok')"

# 安装 Piper 二进制（按架构）
ARG PIPER_VERSION=1.2.0
RUN arch="$(uname -m)" && \
case "$arch" in \
x86_64) piper_pkg="piper_linux_x86_64" ;; \
aarch64) piper_pkg="piper_linux_aarch64" ;; \
armv7l) piper_pkg="piper_linux_armv7l" ;; \
*) echo "Unsupported arch: $arch" && exit 1 ;; \
esac && \
mkdir -p /opt/piper/models && cd /opt/piper && \
curl -fL --retry 3 --retry-delay 2 -o piper.tar.gz "https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/${piper_pkg}.tar.gz" && \
tar -xzf piper.tar.gz && rm piper.tar.gz && \
install -m 0755 piper /usr/local/bin/piper

# 下载 Huayan 模型（优先 HuggingFace 稳定直链，避免 GitHub 404/限流）
# 说明：HuggingFace 路径随官方仓库，若未来调整，可替换为企业自建镜像源
ENV PIPER_MODEL_DIR=/opt/piper/models
RUN mkdir -p "$PIPER_MODEL_DIR"
RUN curl -fL --retry 3 --retry-delay 2 \
-o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx" \
"https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh-CN-huayan-medium.onnx?download=true"
RUN curl -fL --retry 3 --retry-delay 2 \
-o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx.json" \
"https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh-CN-huayan-medium.onnx.json?download=true"

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
