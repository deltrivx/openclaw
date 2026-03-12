# Dockerfile — 开箱即用增强版 OpenClaw（内置 ocrmypdf + clawhub + Tesseract 中文 + GitHub CLI + 浏览器中文化）
# 组件：Chromium + ffmpeg + faster‑whisper（conda+mamba + pip 二进制轮子）
#      + Piper(OHF‑Voice/piper1‑gpl, Huayan via HuggingFace)
#      + Tesseract OCR（chi_sim）+ ocrmypdf + poppler-utils
#      + ClawHub（技能包管理器）+ GitHub CLI（gh）
#      + 浏览器中文化（zh_CN.UTF-8 本地化 + 中文语言首选项）

FROM ghcr.io/openclaw/openclaw:latest

LABEL org.opencontainers.image.title="openclaw-enhanced-cn" \
      org.opencontainers.image.description="OpenClaw + Chromium + ffmpeg + faster-whisper + Piper (Huayan) + Tesseract(chi_sim) + OCRmyPDF + Poppler + ClawHub + gh + zh_CN 中文本地化" \
      org.opencontainers.image.source="https://github.com/openclaw/openclaw"

USER root

ENV DEBIAN_FRONTEND=noninteractive

# 基础系统依赖 + gh（官方APT源）
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      chromium chromium-common chromium-driver \
      fonts-wqy-zenhei fonts-wqy-microhei \
      ffmpeg \
      tesseract-ocr tesseract-ocr-chi-sim \
      ocrmypdf poppler-utils qpdf ghostscript pngquant \
      nodejs npm \
      ca-certificates curl jq tini bash bzip2 gnupg locales; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null; \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends gh git openssh-client; \
    # 中文本地化（生成 zh_CN.UTF-8）
    sed -i 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen || true; \
    locale-gen zh_CN.UTF-8; \
    update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 LANGUAGE=zh_CN:zh; \
    printf 'LANG=zh_CN.UTF-8\nLC_ALL=zh_CN.UTF-8\nLANGUAGE=zh_CN:zh\n' > /etc/default/locale; \
    apt-get purge -y --auto-remove gnupg; \
    rm -rf /var/lib/apt/lists/*

# 运行时中文优先 & 浏览器中文
ENV LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh \
    CHROME_PATH=/usr/bin/chromium \
    CHROME_ARGS=--lang=zh-CN \
    PLAYWRIGHT_CHROMIUM_ARGS=--lang=zh-CN \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    PLAYWRIGHT_BROWSERS_PATH=/usr/bin \
    TZ=Asia/Shanghai \
    TESS_LANG=chi_sim+eng

# 安装 Miniforge（conda-forge）+ mamba
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

# Python 环境（ASR 依赖）
RUN mamba create -y -n gov python=3.10 && conda clean -afy
ENV PATH=$CONDA_DIR/envs/gov/bin:$PATH
RUN mamba install -y -n gov -c conda-forge openblas onnxruntime && conda clean -afy

# 仅二进制轮子安装 ASR 组件
ENV PIP_NO_CACHE_DIR=1 PIP_DEFAULT_TIMEOUT=240 PIP_ONLY_BINARY=:all:
RUN python -V && pip -V
RUN pip install --no-cache-dir --only-binary=:all: "numpy==1.26.4"
RUN pip install --no-cache-dir --only-binary=:all: "ctranslate2==4.3.1" "tokenizers==0.15.1" "faster-whisper==1.0.3"
RUN python -c "import faster_whisper, ctranslate2, tokenizers; print('asr env ok')"

# Piper = OHF‑Voice/piper1‑gpl（可选直链）
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

# Huayan 模型（多源回退）
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

# 安装 ClawHub（技能包管理器）
RUN npm i -g clawhub && clawhub --help >/dev/null 2>&1 || true

# 验证 gh CLI
RUN gh --version && git --version || true

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
  CMD ["bash","-lc","openclaw --version || oc --version || node -v || python -V || exit 1"]

# 官方默认网关端口
EXPOSE 18789
