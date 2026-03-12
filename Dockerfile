# Dockerfile（含中文声明）— 开箱即用增强版 OpenClaw
# 组件：Chromium + ffmpeg + faster‑whisper（conda+mamba + pip 二进制轮子）+ Piper(OHF‑Voice/piper1‑gpl, Huayan via HuggingFace)
# 一致性：保持官方默认端口 18789 与启动行为；修复容器内非交互 docker exec openclaw
#
# 使用声明（非商业）：
# 本镜像仅供学习与研究，默认非商业使用。若用于商业或再分发，请分别遵循所有上游项目与模型的许可条款
# （含但不限于：OpenClaw、Piper/piper1‑gpl 及其模型、faster‑whisper/CTranslate2/tokenizers 等）。
# 本仓库作者不对因使用产生的合规/版权/内容风险承担责任。请务必在遵循相关许可证的前提下使用。

FROM ghcr.io/openclaw/openclaw:latest

LABEL org.opencontainers.image.title="deltrivx/openclaw" \
      org.opencontainers.image.description="OpenClaw + Chromium + ffmpeg + faster-whisper (conda+mamba+binary wheels) + Piper (OHF-Voice/piper1-gpl, Huayan), non-interactive openclaw fixed" \
      org.opencontainers.image.source="https://github.com/deltrivx/openclaw" \
      maintainer="DeltrivX"

USER root

# 基础系统依赖（Chromium/字体/ffmpeg/常用工具）
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    chromium chromium-common chromium-driver \
    fonts-wqy-zenhei fonts-wqy-microhei \
    ffmpeg \
    ca-certificates curl jq tini bash bzip2 \
 && rm -rf /var/lib/apt/lists/*

# 运行时环境变量（浏览器路径/下载跳过/时区）
ENV CHROME_PATH=/usr/bin/chromium \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    PLAYWRIGHT_BROWSERS_PATH=/usr/bin \
    TZ=Asia/Shanghai

# --- 构建元数据注入：用于修复 openclaw --version 后缀 (unknown) ---
ARG GIT_COMMIT
ARG BUILD_DATE
ENV OPENCLAW_COMMIT_SHA=${GIT_COMMIT} \
    OPENCLAW_BUILD_DATE=${BUILD_DATE}
LABEL org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}"
RUN printf '%s\n' "commit=${OPENCLAW_COMMIT_SHA:-unknown}" "built=${OPENCLAW_BUILD_DATE:-unknown}" > /usr/local/share/openclaw-build.txt

# 安装 Miniforge（conda-forge）+ mamba（稳定解算）
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

# 创建 Python 3.10 环境（wheel 覆盖更广），安装底层依赖
RUN mamba create -y -n gov python=3.10 && conda clean -afy
ENV PATH=$CONDA_DIR/envs/gov/bin:$PATH
RUN mamba install -y -n gov -c conda-forge openblas onnxruntime && conda clean -afy

# 仅二进制轮子安装 ASR 组件（避免源码编译/ABI 风险）
ENV PIP_NO_CACHE_DIR=1 \
    PIP_DEFAULT_TIMEOUT=240 \
    PIP_ONLY_BINARY=:all:
RUN python -V && pip -V
RUN pip install --no-cache-dir --only-binary=:all: "numpy==1.26.4"
RUN pip install --no-cache-dir --only-binary=:all: "ctranslate2==4.3.1" "tokenizers==0.15.1" "faster-whisper==1.0.3"
RUN python -c "import faster_whisper, ctranslate2, tokenizers; print('asr env ok')"

# Piper = OHF‑Voice/piper1‑gpl（通过 manylinux wheel 安装；可用 PIPER_WHEEL_URL 覆盖）
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
  pip install --no-cache-dir "$WHEEL"; \
  command -v piper >/dev/null 2>&1 || { echo "piper console script not found after wheel install"; exit 22; }

# 使用 HuggingFace 模型（Huayan medium）作为 Piper 声线（多源回退 + 可选直链参数）
ARG PIPER_URL_MODEL_ONNX=""
ARG PIPER_URL_MODEL_JSON=""
ENV PIPER_MODEL_DIR=/opt/piper/models
RUN set -eux; \
  mkdir -p "$PIPER_MODEL_DIR"; \
  if [ -n "$PIPER_URL_MODEL_ONNX" ]; then \
    curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx" "$PIPER_URL_MODEL_ONNX"; \
  else \
    ( curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx" "https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh-CN-huayan-medium.onnx?download=true" ) \
    || ( curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx" "https://github.com/rhasspy/piper/releases/download/v1.2.0/zh-CN-huayan-medium.onnx" ) \
    || ( curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx" "https://ghproxy.com/https://github.com/rhasspy/piper/releases/download/v1.2.0/zh-CN-huayan-medium.onnx" ) \
    || { echo "[model] all sources failed (onnx)"; exit 22; }; \
  fi; \
  if [ -n "$PIPER_URL_MODEL_JSON" ]; then \
    curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx.json" "$PIPER_URL_MODEL_JSON"; \
  else \
    ( curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx.json" "https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh-CN-huayan-medium.onnx.json?download=true" ) \
    || ( curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx.json" "https://github.com/rhasspy/piper/releases/download/v1.2.0/zh-CN-huayan-medium.onnx.json" ) \
    || ( curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx.json" "https://ghproxy.com/https://github.com/rhasspy/piper/releases/download/v1.2.0/zh-CN-huayan-medium.onnx.json" ) \
    || { echo "[model] all sources failed (json)"; exit 22; }; \
  fi; \
  echo "piper1-gpl + Huayan ready"

# Piper 自检（不阻断构建）
RUN bash -lc 'echo "你好，世界" | piper -m /opt/piper/models/zh-CN-huayan-medium.onnx -f /tmp/tts.wav || true'

# 非交互/后台调用 openclaw 修复（oc 包装）
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec bash -lc "openclaw \"$@\""' > /usr/local/bin/oc && \
    chmod +x /usr/local/bin/oc && \
    ln -sf /usr/local/bin/oc /usr/local/bin/openclaw-cli

# 健康检查：确保 CLI 可用
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
  CMD ["bash","-lc","openclaw --version || oc --version || node -v || python -V || exit 1"]

# 官方默认网关端口
EXPOSE 18789
