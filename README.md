# DeltrivX OpenClaw（Debian 构建版 / 中文环境）

本仓库用于构建并发布镜像：

- 镜像：`deltrivx/openclaw:latest`
- 源码上游：`openclaw/openclaw`（构建时拉取源码并编译）
- 基础运行镜像：`debian:12-slim`

目标：在不改变 OpenClaw 功能的前提下，提供“源码级可打补丁（用于汉化）”的构建流水线，并内置常用工具链。

---

## ✅ 已实现（当前）

- OpenClaw：构建时从上游源码拉取并执行 `pnpm build:docker` 产出 `dist/`，再复制进运行镜像
- 中文环境：`LANG/LC_ALL=zh_CN.UTF-8` + `fonts-noto-cjk`
- 浏览器自动化：Playwright + Chromium（安装目录 `/ms-playwright`），并提供稳定路径：`/usr/bin/chromium`
- 多媒体：ffmpeg
- OCR/PDF：tesseract(chi_sim)、ocrmypdf、poppler-utils
- Python：faster-whisper/ctranslate2、python-playwright、edge-tts、pyyaml（系统 python3，使用 `--break-system-packages`）
- 工具：ClawHub CLI

---

## 🧩 汉化（计划）

当前 Dockerfile 已切换为“源码编译”模式，后续会在 builder 阶段插入汉化补丁（先 CLI/help/关键日志，再逐步覆盖 UI）。

---

## 🔄 CI 构建与推送

见：`.github/workflows/sync-upstream.yml`

---

## 自检

```bash
openclaw --help | head
node -p "require('playwright/package.json').version"
/usr/bin/chromium --version || true
python3 -c "import yaml; print('pyyaml ok')"
```
