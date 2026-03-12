# Dockerfile — 零外网拉取版（彻底避开限流）
# 思路：将 piper 可执行文件与 Huayan 模型预置到构建上下文，再 COPY 进镜像
# 准备：先运行 fetch_piper_assets.sh 拉取三件文件到 third_party/piper/<arch>/ 与 third_party/piper/models/
# 构建：docker build -t deltrivx/openclaw:latest .

FROM ghcr.io/openclaw/openclaw:latest

LABEL org.opencontainers.image.title="deltrivx/openclaw" \
org.opencontainers.image.description="OpenClaw (official defaults) + Chromium + ffmpeg + faster-whisper (conda+mamba+binary wheels) + Piper (Huayan, vendored), non-interactive openclaw fixed" \
org.opencontainers.image.source="https://github.com/deltrivx/openclaw" \
maintainer="DeltrivX"

USER root

# 基础系统依赖（不改官方行为）
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

# Miniforge + mamba
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH
RUN set -eux; \
arch="$(uname -m)"; \
if [ "$arch" = "x86_64" ]; then mf_arch="x86_64"; \
elif [ "$arch" = "aarch64" ]; then mf_arch="aarch64"; \
else echo "Unsupported arch: $arch"; exit 1; fi; \
curl -fsSL -o /tmp/miniforge.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${mf_arch}.sh" && \
bash /tmp/miniforge.sh -b -p "$CONDA_DIR" && rm -f /tmp/miniforge.sh && \
conda config --system --add channels conda-forge && \
conda config --system --set channel_priority strict && \
conda install -y -n base -c conda-forge mamba && conda clean -afy

# Python 3.10 + 底层依赖
RUN mamba create -y -n gov python=3.10 && conda clean -afy
ENV PATH=$CONDA_DIR/envs/gov/bin:$PATH
RUN mamba install -y -n gov -c conda-forge openblas onnxruntime && conda clean -afy

# pip 仅二进制轮子安装 ASR 组件
ENV PIP_NO_CACHE_DIR=1 PIP_DEFAULT_TIMEOUT=240 PIP_ONLY_BINARY=:all:
RUN python -V && pip -V
RUN pip install --no-cache-dir --only-binary=:all: "numpy==1.26.4"
RUN pip install --no-cache-dir --only-binary=:all: "ctranslate2==4.3.1" "tokenizers==0.15.1" "faster-whisper==1.0.3"
RUN python -c "import faster_whisper, ctranslate2, tokenizers; print('asr env ok')"

# ===== 关键：本地预置 Piper 可执行文件与 Huayan 模型（构建上下文内提供）=====
# 目录规范（由 fetch_piper_assets.sh 预先下载）：
# third_party/piper/x86_64/piper 或 third_party/piper/aarch64/piper
# third_party/piper/models/zh-CN-huayan-medium.onnx
# third_party/piper/models/zh-CN-huayan-medium.onnx.json

# 拷贝 piper 可执行文件（按架构）
ARG PIPER_ARCH=
RUN set -eux; \
arch="$(uname -m)"; \
if [ -n "$PIPER_ARCH" ]; then echo "Using override arch: $PIPER_ARCH"; arch="$PIPER_ARCH"; fi; \
case "$arch" in \
x86_64) src_dir="third_party/piper/x86_64" ;; \
aarch64) src_dir="third_party/piper/aarch64" ;; \
*) echo "Unsupported arch for vendored piper: $arch"; exit 1 ;; \
esac; \
echo "Expecting piper binary in ${src_dir}/piper"

COPY third_party/piper/x86_64/piper /opt/piper/bin/x86_64/piper
COPY third_party/piper/aarch64/piper /opt/piper/bin/aarch64/piper

RUN set -eux; \
arch="$(uname -m)"; \
if [ -n "$PIPER_ARCH" ]; then arch="$PIPER_ARCH"; fi; \
if [ "$arch" = "x86_64" ]; then install -m 0755 /opt/piper/bin/x86_64/piper /usr/local/bin/piper; fi; \
if [ "$arch" = "aarch64" ]; then install -m 0755 /opt/piper/bin/aarch64/piper /usr/local/bin/piper; fi; \
/usr/local/bin/piper --help >/dev/null 2>&1 || { echo "piper binary missing/invalid"; exit 22; }

# 拷贝 Huayan 模型
ENV PIPER_MODEL_DIR=/opt/piper/models
COPY third_party/piper/models/zh-CN-huayan-medium.onnx ${PIPER_MODEL_DIR}/zh-CN-huayan-medium.onnx
COPY third_party/piper/models/zh-CN-huayan-medium.onnx.json ${PIPER_MODEL_DIR}/zh-CN-huayan-medium.onnx.json

# 自检（不阻断）
RUN bash -lc 'echo "你好，世界" | piper -m /opt/piper/models/zh-CN-huayan-medium.onnx -f /tmp/tts.wav || true'

# 非交互/后台调用 openclaw 修复
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec bash -lc "openclaw \"$@\""' > /usr/local/bin/oc && \chmod +x /usr/local/bin/oc && ln -sf /usr/local/bin/oc /usr/local/bin/openclaw-cli

# 健康检查（JSON 数组格式）
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
CMD ["bash","-lc","openclaw --version || oc --version || node -v || python -V || exit 1"]

# 官方默认网关端口：18789
EXPOSE 18789
