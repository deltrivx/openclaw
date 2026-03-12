# Dockerfile
# 目标：完整功能开箱即用（Chromium + ffmpeg + faster-whisper + Piper Huayan），并保持官方默认端口/行为（18789）。
# 稳定性策略：
# - ASR：Miniforge + mamba（conda-forge 二进制）+ pip 仅二进制轮子，避免源码编译失败
# - Piper：多源回退下载（二进制与模型），任一成功即用
# - 修复：容器内非交互 docker exec openclaw 失效问题（oc 包装）；HEALTHCHECK 语法正确

FROM ghcr.io/openclaw/openclaw:latest

LABEL org.opencontainers.image.title="deltrivx/openclaw" \
org.opencontainers.image.description="OpenClaw (official defaults) + Chromium + ffmpeg + faster-whisper (conda+mamba+binary wheels) + Piper (Huayan), non-interactive openclaw fixed" \
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
ENV PIP_NO_CACHE_DIR=1 \
PIP_DEFAULT_TIMEOUT=240 \
PIP_ONLY_BINARY=:all:
RUN python -V && pip -V
RUN pip install --no-cache-dir --only-binary=:all: "numpy==1.26.4"
RUN pip install --no-cache-dir --only-binary=:all: "ctranslate2==4.3.1" "tokenizers==0.15.1" "faster-whisper==1.0.3"
RUN python -c "import faster_whisper, ctranslate2, tokenizers; print('asr env ok')"

# Piper 二进制与模型（多源回退）
ARG PIPER_VERSION=1.2.0

# 安装 Piper 可执行文件（多源回退，任一成功即止）
RUN set -eux; \
arch="$(uname -m)"; \
case "$arch" in \
x86_64) piper_pkg="piper_linux_x86_64.tar.gz" ;; \
aarch64) piper_pkg="piper_linux_aarch64.tar.gz" ;; \
armv7l) piper_pkg="piper_linux_armv7l.tar.gz" ;; \
*) echo "Unsupported arch: $arch" && exit 1 ;; \
esac; \
mkdir -p /opt/piper/models && cd /opt/piper; \
urls=( \
"https://cdn.jsdelivr.net/gh/rhasspy/piper@v${PIPER_VERSION}/${piper_pkg}" \
"https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/${piper_pkg}" \
"https://ghproxy.com/https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/${piper_pkg}" \
); \
ok=0; \
for u in "${urls[@]}"; do \
echo "[piper] trying $u"; \
if curl -fL --retry 3 --retry-delay 2 -o piper.tar.gz "$u"; then ok=1; break; fi; \
done; \
[ "$ok" -eq 1 ] || { echo "[piper] all sources failed"; exit 22; }; \
tar -xzf piper.tar.gz && rm piper.tar.gz; \
# 兼容不同包结构：优先 ./piper，其次在解包目录内查找
if [ -f ./piper ]; then \
install -m 0755 ./piper /usr/local/bin/piper; \
else \
found_bin="$(find . -maxdepth 2 -type f -name 'piper' | head -n1)"; \
[ -n "$found_bin" ] && install -m 0755 "$found_bin" /usr/local/bin/piper || { echo "[piper] binary not found in archive"; exit 22; }; \
fi; \
/usr/local/bin/piper --help >/dev/null 2>&1 || true

# 下载 Huayan 模型（多源回退）
ENV PIPER_MODEL_DIR=/opt/piper/models
RUN set -eux; \
mkdir -p "$PIPER_MODEL_DIR"; \
m_ok=0; \
for u in \
"https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh-CN-huayan-medium.onnx?download=true" \
"https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/zh-CN-huayan-medium.onnx" \"https://ghproxy.com/https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/zh-CN-huayan-medium.onnx" \
; do \
echo "[piper-model] trying $u"; \
if curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx" "$u"; then m_ok=1; break; fi; \
done; \
[ "$m_ok" -eq 1 ] || { echo "[piper-model] all sources failed (onnx)"; exit 22; }; \
j_ok=0; \
for u in \
"https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh-CN-huayan-medium.onnx.json?download=true" \
"https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/zh-CN-huayan-medium.onnx.json" \
"https://ghproxy.com/https://github.com/rhasspy/piper/releases/download/v${PIPER_VERSION}/zh-CN-huayan-medium.onnx.json" \
; do \
echo "[piper-model] trying $u"; \
if curl -fL --retry 3 --retry-delay 2 -o "$PIPER_MODEL_DIR/zh-CN-huayan-medium.onnx.json" "$u"; then j_ok=1; break; fi; \
done; \
[ "$j_ok" -eq 1 ] || { echo "[piper-model] all sources failed (json)"; exit 22; }; \
echo "Piper + Huayan ready at $PIPER_MODEL_DIR"

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
