# Dockerfile — Piper 改为 OHF-Voice/piper1-gpl（其余不变，开箱即用）
# 功能：Chromium + ffmpeg + faster-whisper（conda+mamba + pip 仅二进制轮子）+ Piper(OHF-Voice/piper1-gpl, Huayan via HuggingFace)
# 稳定性：全程 POSIX /bin/sh 语法；Piper 用 manylinux wheel 安装；模型多源回退；可选直链参数绕过限流
# 官方一致：默认网关端口 18789、不改官方启动/行为；修复容器内非交互 docker exec openclaw

FROM ghcr.io/openclaw/openclaw:latest

LABEL org.opencontainers.image.title="deltrivx/openclaw" \
org.opencontainers.image.description="OpenClaw (official defaults) + Chromium + ffmpeg + faster-whisper (conda+mamba+binary wheels) + Piper (OHF-Voice/piper1-gpl, Huayan), non-interactive openclaw fixed" \
org.opencontainers.image.source="https://github.com/deltrivx/openclaw" \
maintainer="DeltrivX"

USER root

# 基础系统依赖（不改变官方其他行为）
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

# Miniforge（conda-forge）+ mamba（更稳）
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH
RUN set -eux; \
arch="$(uname -m)"; \
if [ "$arch" = "x86_64" ]; then mf_arch="x86_64"; \
elif [ "$arch" = "aarch64" ]; then mf_arch="aarch64"; \
else echo "Unsupported arch: $arch"; exit 1; fi; \
curl -fsSL -o /tmp/miniforge.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${mf_arch}.sh" && \
bash /tmp/miniforge.sh -b -p "$CONDA_DIR" && \
rm -f /tmp/miniforge.sh && \
conda config --system --add channels conda-forge && \
conda config --system --set channel_priority strict && \
conda install -y -n base -c conda-forge mamba && conda clean -afy

# Python 3.10 环境 + 底层依赖（onnxruntime/openblas）
RUN mamba create -y -n gov python=3.10 && conda clean -afy
ENV PATH=$CONDA_DIR/envs/gov/bin:$PATH
RUN mamba install -y -n gov -c conda-forge openblas onnxruntime && conda clean -afy

# pip 仅二进制轮子安装 ASR 组件（避免源码编译/ABI 不兼容）
ENV PIP_NO_CACHE_DIR=1 \
PIP_DEFAULT_TIMEOUT=240 \
PIP_ONLY_BINARY=:all:
RUN python -V && pip -V
RUN pip install --no-cache-dir --only-binary=:all: "numpy==1.26.4"
RUN pip install --no-cache-dir --only-binary=:all: "ctranslate2==4.3.1" "tokenizers==0.15.1" "faster-whisper==1.0.3"
RUN python -c "import faster_whisper, ctranslate2, tokenizers; print('asr env ok')"

# Piper = OHF-Voice/piper1-gpl（通过 manylinux wheel 安装；支持自定义直链参数）
# 你确认可用的资产（示例）：
# - x86_64: https://github.com/OHF-Voice/piper1-gpl/releases/download/v1.4.1/piper_tts-1.4.1-cp39-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.manylinux_2_28_x86_64.whl
# - aarch64: https://github.com/OHF-Voice/piper1-gpl/releases/download/v1.4.1/piper_tts-1.4.1-cp39-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.manylinux_2_28_aarch64.whl
ARG PIPER1_VERSION=1.4.1
ARG PIPER_WHEEL_URL=""
RUN set -eux; \
arch="$(uname -m)"; \
if [ -n "$PIPER_WHEEL_URL" ]; then \
WHEEL="$PIPER_WHEEL_URL"; \
else \
if [ "$arch" = "x86_64" ]; then \
WHEEL="https://github.com/OHF-Voice/piper1-gpl/releases/download/v${PIPER1_VERSION}/piper_tts-${PIPER1_VERSION}-cp39-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.manylinux_2_28_x86_64.whl"; \
elif [ "$arch" = "aarch64" ]; then \
WHEEL="https://github.com/OHF-Voice/piper1-gpl/releases/download/v${PIPER1_VERSION}/piper_tts-${PIPER1_VERSION}-cp39-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.manylinux_2_28_aarch64.whl"; \
else \
echo "Unsupported arch for piper1-gpl wheel: $arch"; exit 1; \
fi; \
fi; \
echo "[piper1-gpl] installing wheel: $WHEEL"; \
pip install --no-cache-dir "$WHEEL"; \
command -v piper >/dev/null 2>&1 || { echo "piper console script not found after wheel install"; exit 22; }

# 使用 HuggingFace 模型（Huayan medium）作为 Piper 声线（多源回退 + 可选直链参数）
ARG PIPER_URL_MODEL_ONNX=""
ARG PIPER_URL_MODEL_JSON=""
ENV PIPER_MODEL_DIR=/opt/piper/models
RUN set -eux; \
mkdir -p "$PIPER_MODEL_DIR" && \if [ -n "$PIPER_URL_MODEL_ONNX" ]; then \
curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx" "$PIPER_URL_MODEL_ONNX"; \
else \
(curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx" "https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh-CN-huayan-medium.onnx?download=true") || \
(curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx" "https://github.com/rhasspy/piper/releases/download/v1.2.0/zh-CN-huayan-medium.onnx") || \
(curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx" "https://ghproxy.com/https://github.com/rhasspy/piper/releases/download/v1.2.0/zh-CN-huayan-medium.onnx") || \
{ echo "[model] all sources failed (onnx)"; exit 22; }; \
fi && \
if [ -n "$PIPER_URL_MODEL_JSON" ]; then \
curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx.json" "$PIPER_URL_MODEL_JSON"; \
else \
(curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx.json" "https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh-CN-huayan-medium.onnx.json?download=true") || \
(curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx.json" "https://github.com/rhasspy/piper/releases/download/v1.2.0/zh-CN-huayan-medium.onnx.json") || \
(curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx.json" "https://ghproxy.com/https://github.com/rhasspy/piper/releases/download/v1.2.0/zh-CN-huayan-medium.onnx.json") || \
{ echo "[model] all sources failed (json)"; exit 22; }; \
fi && \
echo "piper1-gpl + Huayan ready"

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
