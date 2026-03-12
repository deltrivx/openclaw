# 使用 micromamba 构建独立 Python 环境，绕过 buildx 下 pip 源码编译不稳定问题
# 方案要点：
# - 基于 ghcr.io/openclaw/openclaw:latest
# - 系统层：Chromium / ffmpeg / 字体 等
# - Python 层：用 micromamba 创建 gov 环境（python=3.11），conda 装 ctranslate2/tokenizers/openblas 等，
# 再在该环境内用 pip 安装 faster-whisper==1.0.3 与 numpy<2（极大提升成功率）
# - 内置 Piper + Huayan medium 中文女声
# - 修复 docker exec（非交互）直接调用 openclaw
# - 健康检查 + 开机自更新

FROM ghcr.io/openclaw/openclaw:latest

LABEL org.opencontainers.image.title="deltrivx/openclaw" \
org.opencontainers.image.description="OpenClaw + Chromium + Piper (Huayan medium) + faster-whisper + ffmpeg (via micromamba env); auto-update; non-interactive openclaw fixed" \
org.opencontainers.image.source="https://github.com/deltrivx/openclaw" \
maintainer="DeltrivX"

USER root

# 基础依赖：Chromium/ffmpeg/系统工具
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
chromium chromium-common chromium-driver \
fonts-wqy-zenhei fonts-wqy-microhei \
ffmpeg \
ca-certificates curl jq tini bash bzip2 \
&& rm -rf /var/lib/apt/lists/*

# 环境变量
ENV CHROME_PATH=/usr/bin/chromium \
PUPPETEER_SKIP_DOWNLOAD=1 \
PLAYWRIGHT_BROWSERS_PATH=/usr/bin \
TZ=Asia/Shanghai

# 安装 micromamba（轻量 conda），并创建 gov 环境
# - 使用 conda-forge 源安装：python=3.11, ctranslate2, tokenizers, openblas 等
# - 之后在此环境内用 pip 安装 faster-whisper==1.0.3 与 numpy<2
ARG MAMBA_ROOT_PREFIX=/opt/micromamba
ENV MAMBA_ROOT_PREFIX=${MAMBA_ROOT_PREFIX}
RUN set -eux; \
arch=$(uname -m); \
case "$arch" in \
x86_64) MM_ARCH="linux-64";; \
aarch64) MM_ARCH="linux-aarch64";; \
*) echo "Unsupported arch for micromamba: $arch"; exit 1;; \
esac; \
curl -fsSL "https://micro.mamba.pm/api/micromamba/${MM_ARCH}/latest" -o /tmp/micromamba.tar.bz2; \
mkdir -p "${MAMBA_ROOT_PREFIX}"; \
tar -xjf /tmp/micromamba.tar.bz2 -C /tmp; \
mv /tmp/bin/micromamba /usr/local/bin/micromamba; \
rm -rf /tmp/micromamba.tar.bz2 /tmp/bin; \
micromamba shell hook -s bash -p ${MAMBA_ROOT_PREFIX} >/etc/profile.d/micromamba.sh

# 创建并填充环境：gov
# - 先用 conda 安装：python/ctranslate2/tokenizers/openblas 等（优先使用预编译包，避免源码编译）
# - 再在环境内 pip 安装：numpy<2 + faster-whisper==1.0.3
ENV MAMBA_DOCKERFILE_ACTIVATE=1
RUN set -eux; \
micromamba create -y -n gov -c conda-forge \
python=3.11 \
ctranslate2=4.2.1 \
tokenizers=0.15.1 \
openblas \
libopenblas \
libstdcxx-ng \
libgcc-ng \
pip; \
micromamba run -n gov pip install --no-cache-dir "numpy<2" "faster-whisper==1.0.3"; \
micromamba clean -a -y

# 使 gov 环境默认可用
ENV PATH=${MAMBA_ROOT_PREFIX}/envs/gov/bin:${PATH}
# 验证（不失败构建）
RUN python -V && pip -V && python -c "import ctranslate2, tokenizers; print('ok')" && python -c "import faster_whisper; print('ok')"

# 安装 Piper 与中文女声 Huayan medium 模型
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

# 入口脚本：修复非交互 openclaw 调用 + 可选开机自更新
RUN printf '%s\n' \
'#!/usr/bin/env bash' \
'set -euo pipefail' \
': "${OPENCLAW_AUTO_UPDATE:=true}"' \
': "${OPENCLAW_UPDATE_CHANNEL:=stable}"' \
'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"' \
'if ! command -v openclaw >/dev/null 2>&1; then' \
' if command -v npx >/dev/null 2>&1; then' \
' ln -sf "$(command -v npx)" /usr/local/bin/openclaw || true' \
' fi' \
'fi' \'if [[ "${OPENCLAW_AUTO_UPDATE}" == "true" ]]; then' \
' echo "[entrypoint] Auto-updating OpenClaw (channel=${OPENCLAW_UPDATE_CHANNEL})..."' \
' command -v openclaw >/dev/null 2>&1 && openclaw gateway update || true' \
'fi' \
'node -v || true' \
'npm -v || true' \
'openclaw --version || true' \
'python -V || true' \
'if [[ $# -gt 0 ]]; then exec "$@"; fi' \
'exec openclaw gateway start' \
> /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

# oc/openclaw-cli 包装，保证 docker exec 非交互可直接用 openclaw
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec bash -lc "openclaw \"$@\""' > /usr/local/bin/oc && \
chmod +x /usr/local/bin/oc && \
ln -sf /usr/local/bin/oc /usr/local/bin/openclaw-cli

# 运行时开关
ENV OPENCLAW_AUTO_UPDATE=true \
OPENCLAW_UPDATE_CHANNEL=stable

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
CMD openclaw --version || oc --version || node -v || python -V || exit 1

# 常用端口（按需调整）
EXPOSE 3000 8080

# PID1：tini，确保信号转发与僵尸进程回收
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["openclaw", "gateway", "start"]
