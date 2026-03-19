<h1 align="center">🦞 OpenClaw增强版 🦞</h1>

> 🧩 基于上游 `ghcr.io/openclaw/openclaw:latest` 的增强镜像仓库，面向 Docker 的“开箱即用”部署。

- 📦 镜像：`ghcr.io/deltrivx/openclaw:latest`
- 🛠️ 构建：push 到 `main` 触发 GitHub Actions 自动构建并推送到 GHCR
- 🔒 说明：仓库已显式提交 `pnpm-lock.yaml`，用于保证 Docker / GHCR 云端构建可复现
- 🧪 预检：在进入 Docker 构建前，Actions 会先对 onboarding 关键源码做轻量语法检查，尽早拦截括号/闭合类错误

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
- ✅ Playwright 默认使用系统 Chromium（不在运行时下载浏览器）
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

#### 🗣️ TTS：本地离线 Piper（OpenAI-compatible）

- Piper 通过 **OpenAI-compatible** 接口提供给 OpenClaw
- Piper TTS API（容器内）：`http://127.0.0.1:18793/v1/audio/speech`
  - 默认端口使用 **18793**（避免与 OpenClaw 浏览器/relay 组件端口冲突）
- 默认音色（voice）：`zh-xiao_ya-medium`（更偏日常、更自然）
- 输出：`mp3`
  - 由 Piper API 服务端负责转码
  - 依赖镜像内置 `ffmpeg`

#### 🤖 QQBot 语音回复

链路：OpenClaw 触发 TTS → qqbot 插件发送语音消息

---

### 6) 🧰 工具链与排障

- ✅ ClawHub CLI：`clawhub`
- ✅ `jq`：JSON 解析/过滤（排障、脚本处理 API 返回值时很常用）
- ✅ `bun`：内置 Bun runtime（固定版本，便于复现构建）

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
        "voice": "zh-xiao_ya-medium"
      }
    }
  }
}
```

---

## 🐳 安装与运行

---

## 🈶 汉化与中文指引（可选）

> 本增强镜像仓库主要做 **Docker 运行时增强**（依赖、TTS、OCR、浏览器等）。
> 
> - **OpenClaw CLI / onboard 交互界面本身的“完整汉化”**需要上游 OpenClaw 提供 i18n/locale 支持（目前 `openclaw onboard --help` 未提供 `--lang` 这类参数）。
> - 本仓库在不破坏英文命令/兼容性的前提下，提供**中文使用指引**（下方速查表），并建议通过环境变量统一设置中文环境。

> 结论先说：
> - **本仓库已经开始在上游源码基础上推进实际汉化**，优先覆盖 Web UI、onboard、CLI 帮助文案与关键交互提示。
> - 当前状态不是“仅中文指引”，而是**源码级中文增强进行中**。
> - 后续会继续补齐剩余交互文案，并逐步扩展到更多用户可见界面。

### 0) 中文 wrapper：openclaw-zh（可选）

```bash
openclaw-zh help
openclaw-zh onboard
```

### 1) 建议的中文环境变量

在 Docker 环境变量中加入（对 CLI 交互/字体渲染更友好；不改变命令语义）：

```bash
TZ=Asia/Shanghai
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
```

### 2) 常用命令中文速查（不改变命令）

- `openclaw onboard`：初始化向导（配置网关、工作区、技能）
- `openclaw configure`：交互式配置向导（凭据/渠道/网关）
- `openclaw gateway run`：前台启动网关
- `openclaw gateway probe`：探测网关连通性/健康
- `openclaw browser start`：启动内置浏览器
- `openclaw browser status`：查看内置浏览器状态

> 如果你是在聊天渠道里使用“/start”等命令，建议把中文说明收敛到 `/help` 输出中（例如：`/start：开始新会话`），避免每次执行命令都额外刷屏。


> 路径/挂载约定参考官方 Docker 文档：https://docs.openclaw.ai/install/docker

下面给出两种常见方式：`docker run`（Docker CLI）与 `docker-compose`。示例以 **GHCR 镜像**为准：`ghcr.io/deltrivx/openclaw:latest`。


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

    # ⚠️ Tailscale 重要说明（Unraid/局域网代理常见坑）
    #
    # OpenClaw 镜像内会启动 tailscaled 用于 `tailscale serve`（让 Dashboard/WS 走 Tailnet 认证）。
    # 但在某些环境里（尤其 Unraid + HTTP 代理/透明代理），如果容器继承了 HTTP_PROXY/HTTPS_PROXY/ALL_PROXY，
    # tailscaled 可能会出现：unexpected EOF / controlplane 连接失败 / hostname mismatch 等问题，导致 serve 不稳定。
    #
    # ✅ 本仓库的修复策略：仅对 tailscaled 进程禁用代理环境变量（其他进程仍可使用代理）。
    #    入口脚本里会使用类似 `env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u NO_PROXY tailscaled ...` 的方式启动。
    #
    # 如果你仍遇到 Tailscale 不稳定：
    # 1) 确认容器已更新到最新镜像（拉取 latest 后重启）
    # 2) 不要给 tailscaled 配代理；如必须全局代理，请务必在 NO_PROXY 中加入：
    #    - controlplane.tailscale.com, log.tailscale.com, derp*.tailscale.com
    #    - localhost,127.0.0.1,::1
    #    - 100.64.0.0/10（Tailscale 网段）

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

## 🈶 汉化与中文指引（可选）

- 本仓库采用“构建期补丁”方式，为 onboard/安全页等提供中文界面。详见  与 。
- OpenClaw 本体暂未提供完整 i18n，因此这是不修改上游源码的最小侵入式方案。
