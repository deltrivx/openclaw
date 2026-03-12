# deltrivx/openclaw · 开箱即用增强版（Chromium + Piper 中文女声 + faster‑whisper + ffmpeg）

> 基于官方镜像 `ghcr.io/openclaw/openclaw:latest` 的工程化整合，面向“开箱即用、稳定构建、易部署”。
> 内置 Chromium、ffmpeg、faster‑whisper（二进制轮子安装）、Piper（中文女声 Huayan medium），修复容器内非交互 `openclaw` 调用；提供 Unraid 友好 docker‑compose；集成每日自动重建 GHCR 工作流；构建时注入版本元数据，摆脱 `(unknown)`。

---

## ✨ 特色能力
- 浏览器与多媒体：Chromium（含驱动）+ ffmpeg，网页自动化与音视频处理即刻可用。
- 语音链路：faster‑whisper（ASR）采用 conda + pip **仅二进制轮子**安装；Piper（TTS）采用 **OHF‑Voice/piper1‑gpl** manylinux wheel 安装，内置中文女声 **Huayan medium** 模型（HuggingFace 多源回退）。
- 非交互 CLI 修复：提供 `oc` 包装，`docker exec <ctr> openclaw …` 在非交互/后台可用。
- 版本号补全：构建注入 `GIT_COMMIT / BUILD_DATE`，`openclaw --version` 不再显示 `(unknown)`，另落盘 `/usr/local/share/openclaw-build.txt` 便于审计。
- CI 与镜像管理：GitHub Actions 每日定时多架构构建并推送 GHCR，可一键公开镜像。

---

## 🚀 快速部署（Unraid / docker‑compose）
将以下内容保存为仓库根的 `docker-compose.yml`：
```yaml
version: "3.9"

services:
  openclaw:
    image: ghcr.io/deltrivx/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    environment:
      TZ: "Asia/Shanghai"
    ports:
      - "18789:18789"              # OpenClaw 网关端口（官方默认）
    volumes:
      - /root/.openclaw:/root/.openclaw   # 官方工作区挂载
    healthcheck:
      test: ["CMD", "bash", "-lc", "openclaw --version || oc --version || node -v || python -V"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
```
启动：
```bash
docker compose up -d
```
访问控制面板：`http://<你的主机IP>:18789/`

---

## 🗣️ 语音能力自检
```bash
docker exec -i openclaw bash -lc 'echo "你好，世界" | piper -m /opt/piper/models/zh-CN-huayan-medium.onnx -f /root/.openclaw/data/tts.wav && ls -l /root/.openclaw/data/tts.wav'
```
> 模型来源：HuggingFace `rhasspy/piper-voices`（见下文致谢）

---

## 🔁 自动构建与推送（GHCR）
工作流文件：`.github/workflows/build-and-push.yml`
- 每日 02:15 UTC 自动重建 `ghcr.io/deltrivx/openclaw:latest`
- 首次需在仓库 Settings → Actions → General 开启 **Read and write permissions**
- 若组织策略限制 GHCR，可在 Secrets 设置 `GHCR_PAT`（scopes: `write:packages, repo`）并在登录步骤使用

---

## 🧩 版本号不再 (unknown)
Dockerfile 注入：
```dockerfile
ARG GIT_COMMIT
ARG BUILD_DATE
ENV OPENCLAW_COMMIT_SHA=${GIT_COMMIT} \
    OPENCLAW_BUILD_DATE=${BUILD_DATE}
LABEL org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}"
RUN printf '%s\n' "commit=${OPENCLAW_COMMIT_SHA:-unknown}" "built=${OPENCLAW_BUILD_DATE:-unknown}" > /usr/local/share/openclaw-build.txt
```
验证：
```bash
openclaw --version
cat /usr/local/share/openclaw-build.txt
```

---

## 🙏 致谢与来源（作者/版权归属）
- OpenClaw 核心项目与镜像：
  - 项目：https://github.com/openclaw/openclaw
  - 镜像：`ghcr.io/openclaw/openclaw`
- Piper（本地 TTS 引擎）：
  - rhasspy/piper（作者：Michael Hansen / Rhasspy 团队）：https://github.com/rhasspy/piper
  - OHF‑Voice/piper1‑gpl（作者：OHF‑Voice）：https://github.com/OHF-Voice/piper1-gpl
  - 中文女声 Huayan medium 模型：HuggingFace `rhasspy/piper-voices`：https://huggingface.co/rhasspy/piper-voices
- ASR：
  - faster‑whisper（SYSTRAN / Guillaume Klein 等）：https://github.com/SYSTRAN/faster-whisper
  - CTranslate2（OpenNMT）：https://github.com/OpenNMT/CTranslate2
  - tokenizers（Hugging Face）：https://github.com/huggingface/tokenizers

本仓库仅做工程化整合与封装，**尊重并遵循上游许可证与版权声明**。引用的商标与名称均归属其原权利人。

---

## ⚠️ 许可与使用声明（非商业）
- 本仓库以“仅供学习与研究”为目的发布，默认 **非商业使用**。
- 如需商用/再分发，请分别确认并遵循所有上游项目与模型的许可证（包括但不限于 OpenClaw、Piper/piper1‑gpl 及其模型、faster‑whisper/CTranslate2/tokenizers 等）。
- 如涉及商业化或内容安全，请自行进行合规审查与授权确认；本仓库作者不对因使用产生的合规/版权/内容风险承担责任。
