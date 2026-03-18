<h1 align="center">🦞 OpenClaw增强版 🦞</h1>


## 适用于任何操作系统的 AI 智能体 Gateway 网关，支持 WhatsApp、Telegram、Discord、iMessage 等。


- 基于上游 `ghcr.io/openclaw/openclaw:latest` 的增强镜像仓库，面向 Docker 的“开箱即用”部署。

- 📦 镜像：`ghcr.io/deltrivx/openclaw:latest`
- 🛠️ 构建：push 到 `main` 触发 GitHub Actions 自动构建并推送到 GHCR

---


## 🧭 目录

- [✅ 功能要点（镜像内置 / 当前状态）](#-功能要点镜像内置--当前状态)
- [⚙️ 配置示例（openclawjson）](#️-配置示例openclawjson)
- [🐳 安装与运行](#-安装与运行)
- [⚓ Docker 运行约定](#-docker-运行约定)
- [🧾 非商业声明与免责协议](#-非商业声明与免责协议)
- [📚 外部来源与署名](#-外部来源与署名)

---

## ✅ 功能要点（镜像内置 / 当前状态）

### 1) 🏗️ 镜像构建 / 同步

- 基础镜像：`ghcr.io/openclaw/openclaw:latest`
- GitHub Actions：push 到 `main` 自动构建并推送 `ghcr.io/deltrivx/openclaw:latest`

---

### 2) 🌐 浏览器自动化

- ✅ 安装系统 Chromium
- ✅ 路径固定为：`/usr/bin/chromium`
- ✅ Playwright 默认使用系统 Chromium（不在运行时下载浏览器，并补全依赖，确保可以正常使用）
  - `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`
  - `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium`

---

### 3) 🎞️ 多媒体

- ✅ 内置 `ffmpeg`

---

### 4) 🧾 OCR / PDF

- ✅ Tesseract OCR（含简体中文 `chi_sim`）
- ✅ OCRmyPDF（扫描 PDF 转可检索）
- ✅ Poppler 工具（如 `pdftotext`）

---

### 5) 🔊 语音链路（当前构建环境）

#### 🗣️ TTS：本地离线 Piper（OpenAI 兼容）

- 通过镜像内置的 **OpenAI 兼容** TTS 服务（Node.js + Piper + FFmpeg）提供给 OpenClaw
- TTS API（容器内）：`http://127.0.0.1:18793/v1/audio/speech`

> 说明：该接口为 OpenAI `POST /v1/audio/speech` 兼容实现：
> - Piper 生成 `wav`
> - FFmpeg 转码为 `mp3`（或直接返回 `wav`）
> - `voice` 对应 `$PIPER_MODELS_DIR/<voice>.onnx`

- 默认端口：**18793**（避免与 OpenClaw 浏览器/relay 组件端口冲突）
- 默认音色（voice）：`zh_CN-huayan-medium`
- 默认输出：`mp3`

#### 接口兼容性说明

该接口为 OpenAI `POST /v1/audio/speech` 的兼容实现，当前支持：

- `input`（必填）
- `voice`（可选；对应 `$PIPER_MODELS_DIR/<voice>.onnx`）
- `response_format（返回格式）`：`mp3` / `wav`

暂不支持/不完全支持：

- `speed`（会被忽略）
- 其它未列出的 OpenAI 扩展字段
  - 由 Piper API 服务端负责转码
  - 依赖镜像内置 `ffmpeg`
  - 构建镜像时补齐Piper相关依赖，避免0kb的bug
#### 🤖 QQBot 语音回复（需要额外配置）

链路：OpenClaw 触发 TTS → qqbot 插件发送语音消息

> 说明：本镜像只提供 TTS 接口与 OpenClaw 运行环境，并不内置/自动登录 QQBot。
> 你需要先在 OpenClaw 中配置 QQBot 通道（账号/Token/WebSocket 等）并启用对应插件，才能让“语音回复”真正发送到 QQ。

最小建议：
- 先确认 OpenClaw 能收到 QQ 的入站消息
- 再开启 `messages.tts.auto`（inbound）并指向本镜像的 `baseUrl=http://127.0.0.1:18793/v1`


---

### 6) 🧰 工具链与排障

- ✅ ClawHub CLI：`clawhub`（已内置）
- ✅ `jq`：JSON 解析/过滤（排障、脚本处理 API 返回值时很常用）
- ✅ `bun`：内置 Bun 运行时（默认安装最新版，便于快速使用；如需固定版本可自行修改 Dockerfile）

---

### 7) 📁 Skills 默认安装目录

- ✅ 统一到：`/root/.agents/skills/`

---

## ⚙️ 配置示例（openclaw.json）

> ⚠️ 注意：不要使用 `messages.tts.openai.format`，部分 OpenClaw 版本不支持该字段，会导致配置校验失败。

```json5
{
  "messages": {
    "tts": {
      "auto": "inbound",
      "provider": "openai",
      "openai": {
        "baseUrl": "http://127.0.0.1:18793/v1",
        "apiKey": "none",
        "model": "tts-1",
        "voice": "zh_CN-huayan-medium"
      }
    }
  }
}
```

---

## 🐳 安装与运行

---

### 方式 A：Docker CLI（docker run）

```bash
# 1) 拉取镜像
docker pull ghcr.io/deltrivx/openclaw:latest

# 2) 运行（按需调整挂载路径与端口）
docker run -d --name openclaw \
  --restart unless-stopped \
  -p 18789:18789 \
  -v $HOME/.openclaw:/root/.openclaw \
  -v $HOME/.openclaw/workspace:/root/.openclaw/workspace \
  ghcr.io/deltrivx/openclaw:latest
```

### 方式 B：docker-compose

保存为 `docker-compose.yml`：

```yaml
services:
  openclaw:
    image: ghcr.io/deltrivx/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    ports:
      - "18789:18789"
    volumes:
      - $HOME/.openclaw:/root/.openclaw
      - $HOME/.openclaw/workspace:/root/.openclaw/workspace
    # 如需代理，取消注释并填写：
    # environment:
    #   HTTP_PROXY: http://192.168.1.2:7890
    #   HTTPS_PROXY: http://192.168.1.2:7890
    #   NO_PROXY: localhost,127.0.0.1,::1,0.0.0.0,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12

# 可选：使用 compose v2
# docker compose up -d
```

运行：

```bash
docker compose up -d
```

---

## ⚓ Docker 运行约定

- 系统 Python 保持 `/usr/bin/python3` 可用
- 同时提供 `/opt/venv`，并通过 `PATH` 优先使用 venv
- 系统 pip3 用于排障；运行时依赖以 venv 为准

---


## 🧾 非商业声明与免责协议

### 非商业声明

本仓库以学习、研究与自用部署为目的整理与集成相关组件。除非另行声明：

- 🚫 **不提供任何商业化保证**（包括但不限于可用性、稳定性、性能、适配性）
- 🚫 **不对任何第三方服务/平台的可用性负责**（例如上游镜像仓库、依赖下载源、第三方 API 等）

### 免责声明

使用本仓库/镜像即表示你理解并同意：

- 你需要自行评估并承担部署、暴露端口、网络访问、账号密钥与数据安全等风险
- 因使用本仓库/镜像造成的任何直接或间接损失（数据丢失、服务中断、账号风险、费用支出等），维护者不承担责任

> 建议：不要把管理面板/控制端口直接暴露到公网；局域网访问也应启用可靠认证与访问控制。

---

## 📚 外部来源与署名

本文档仅使用 Unicode Emoji（不引入外部图标素材）。涉及的第三方项目/服务与资源均归原作者/组织所有，特此致谢（感谢所有开源贡献者）：

- OpenClaw（上游镜像与项目）：https://github.com/openclaw/openclaw
- Piper TTS（离线 TTS 引擎）：https://github.com/rhasspy/piper
- Piper voices（模型/语音数据来源，具体语音版权以其仓库与模型卡为准）：https://huggingface.co/rhasspy/piper-voices
- FFmpeg（音视频工具）：https://ffmpeg.org/
- Tesseract OCR：https://github.com/tesseract-ocr/tesseract
- OCRmyPDF：https://github.com/ocrmypdf/OCRmyPDF
- Poppler：https://poppler.freedesktop.org/

---

## 🧯 TTS（Piper）0KB 语音排障（已修复）

> 你之前遇到的 0KB 语音问题，已在镜像构建中通过“补依赖 + 保留完整 Piper bundle + 防 EPIPE + 统一二进制路径”解决。

- 关键依赖：`libespeak-ng1`
- 关键动态库：`libpiper_phonemize.so.1`（随 Piper bundle 提供）
- 关键修复：避免 `EPIPE` 造成 TTS 服务崩溃
- 路径规范：构建时统一 `piper` 到 `/opt/piper/bin/piper`

更详细说明见本段下方“快速检查点”。

### 快速检查点

- 容器日志出现：`[tts] listening on http://127.0.0.1:18793`
- 触发一次语音后出现：
  - `[tts] request: ...`
  - `[tts] response: audio/mpeg bytes=...`

---

## 🔎 重要说明（避免踩坑）

### GitHub Actions 构建触发条件

当前仓库的 GitHub Actions **只在 push 到 `main` 且变更命中以下文件时**才会触发构建并推送 GHCR：

- `Dockerfile`
- `.github/workflows/build.yml`

> 仅修改 `README.md` / `piper-entrypoint.sh` / `openai_tts_server.py` 等文件**不会**触发构建（除非同时改到上述文件）。

### TTS 端口是否可被容器外访问

镜像内置的 OpenAI 兼容 TTS 服务默认绑定在本机回环：

- `TTS_BIND=127.0.0.1`
- `TTS_PORT=18793`

这意味着：即便你在 `docker run` 里做了 `-p 18793:18793`，如果不改 `TTS_BIND`，宿主机/局域网也访问不到该端口。

如需对外提供（⚠️ 注意安全风险），请显式设置：

```bash
-e TTS_BIND=0.0.0.0
```



---

## 🌏 汉化/本地化（中文环境）

本镜像已默认启用中文本地化环境：

- `TZ=Asia/Shanghai`
- `LANG=zh_CN.UTF-8` / `LC_ALL=zh_CN.UTF-8`
- 内置中文字体：`fonts-noto-cjk`

- 说明：这主要影响容器内的时间显示、日志输出、以及浏览器/截图/HTML 渲染时的中文字体显示。
- OpenClaw 自身 UI/提示词是否中文，仍取决于你使用的模型与 prompt。
- Docker 运行环境中文化（locale / 字体 / 时区）
- 镜像内 OCR / TTS / 浏览器依赖增强

## TTS 依赖与修复总结（Piper / OpenAI-compatible）

本镜像集成了一个 **Piper TTS** 服务，并以 **OpenAI-compatible** 的形式在容器内提供：
- 默认地址：`http://127.0.0.1:18793`
- 用途：给 OpenClaw 的 TTS 能力提供一个本地、可自托管的后端

为保证容器内 TTS 稳定可用，我们在迭代中处理过这些关键依赖/坑位：

- **WORKDIR/启动路径问题**：错误的 `WORKDIR` 会导致 `openclaw.mjs` 启动失败；已移除/修正为不影响 OpenClaw 启动的结构。
- **uvicorn 导入路径问题**：需要在正确目录启动 `uvicorn`（通过在 `/opt/openclaw-enhanced/docker` 目录内子 shell 启动来规避 import path 偏差）。
- **缺失依赖 `pathvalidate`**：Piper 相关代码路径处理依赖它，缺失会导致运行期报错；已补齐。
- **返回音频的方式**：TTS 接口需要直接返回音频字节流；如果用 `FileResponse` 指向临时文件，临时目录清理后会出现“文件不存在/空响应”。已改为 **直接返回 bytes**，并在清理临时文件之前完成读取。
