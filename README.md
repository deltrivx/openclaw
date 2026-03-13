# DeltrivX OpenClaw 增强版镜像（All‑in‑One 工具链容器）

本仓库用于构建并发布镜像：

- 镜像：`deltrivx/openclaw:latest`
- 上游基础镜像：`ghcr.io/openclaw/openclaw:latest`
- 目标：在 **不改变 OpenClaw 原有功能** 的前提下，把常用的浏览器自动化 / 音视频 / 语音 / OCR / PDF 工具链直接内置到同一个容器里，开箱即用。

> 说明：本仓库仅做“打包与集成”。OpenClaw 版权与商标归 OpenClaw 项目所有；第三方组件版权归各自作者所有。

---

## ✨ 内置能力（当前镜像基线）

- Node.js 20+（基于上游镜像，必要时自动补齐）
- Playwright（Node 版）
  - 全局可 `require('playwright')`
  - 已内置 Playwright Chromium（`/ms-playwright`），`chromium.launch()` 可直接用
- ffmpeg（音视频处理）
- faster‑whisper（Python 包，尽量使用二进制 wheel 安装）
- Python Playwright（安装在系统 python3，可直接 `python3 -c "import playwright"`）
- PyYAML（`pyyaml`，用于 Python 脚本解析 YAML）
- Piper TTS（内置二进制）
  - 中文女声：Huayan medium
- Tesseract OCR（含简体中文 `chi_sim`）
- OCRmyPDF（扫描 PDF → 可检索 PDF）
- Poppler（`pdftotext` 等 PDF 工具）
- ClawHub CLI（技能包管理器）
- GitHub CLI（`gh`）
- 交互终端兼容性增强：`tini` + `TERM=xterm-256color`

> 说明：本镜像使用容器内 **真实浏览器自动化**（Playwright + 内置 Chromium `/ms-playwright`），不依赖任何远程静态截图服务（如 mShots）。

---

## 🚀 快速开始

### 1) 拉取镜像

```bash
docker pull deltrivx/openclaw:latest
```

### 2) 运行（最简）

```bash
docker run --rm -it --name openclaw deltrivx/openclaw:latest
```

### 3) docker‑compose（适合 Unraid / 家用服务器）

保存为 `docker-compose.yml`：

```yaml
services:
  openclaw:
    image: deltrivx/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    environment:
      TZ: "Asia/Shanghai"
    volumes:
      - /mnt/user/appdata/openclaw:/root/.openclaw
      - /mnt/user/appdata/openclaw/.clawhub:/root/.clawhub
    ports:
      - "18789:18789"  # OpenClaw 网关端口（以你实际配置为准）
```

启动：

```bash
docker compose up -d
```

---

## ✅ 自检清单（确认环境可用）

### Playwright（Node）

```bash
node -p "require('playwright/package.json').version"
node - <<'NODE'
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ headless: true });
  const p = await b.newPage();
  await p.goto('https://example.com', { waitUntil: 'domcontentloaded' });
  console.log(await p.title());
  await b.close();
})();
NODE
```

### Playwright（Python）

```bash
python3 -c "import importlib.metadata as m; print(m.version('playwright'))"
python3 - <<'PY'
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(headless=True)
    page = b.new_page()
    page.goto('https://example.com', wait_until='domcontentloaded')
    print(page.title())
    b.close()
PY
```

### PyYAML

```bash
python3 -c "import yaml; print('pyyaml ok')"
```

### OCR / PDF

```bash
tesseract --version | head
ocrmypdf --version
pdftotext -v 2>&1 | head -n 1
```

### 音视频

```bash
ffmpeg -version | head -n 2
```

---

## 🔄 上游同步与自动构建

仓库包含 GitHub Actions（`.github/workflows/sync-upstream.yml`）：

- push / PR / schedule / 手动触发（workflow_dispatch）均可构建
- 构建完成后推送：`deltrivx/openclaw:latest`

---

## 🧾 组件来源与作者声明（避免侵权）

本镜像集成多个开源项目，来源与作者（不完整但覆盖核心组件）：

- **OpenClaw**：上游基础镜像 `ghcr.io/openclaw/openclaw:latest`
- **Playwright**：Microsoft Playwright（npm 包 / Python 包）
- **Playwright Chromium**：由 Playwright 官方分发的浏览器构建（随 `npx playwright install chromium` 下载）
- **ffmpeg**：FFmpeg 项目（系统包）
- **faster‑whisper / ctranslate2**：PyPI（优先二进制 wheel）
- **Piper**：rhasspy/piper（GitHub Releases 二进制）
- **Huayan voice model**：rhasspy/piper‑voices（若直链缺失则使用公开镜像源）
- **Tesseract OCR**：Tesseract 项目（系统包）
- **OCRmyPDF**：OCRmyPDF 项目（系统包）
- **Poppler**：Poppler 项目（系统包）
- **ClawHub CLI**：clawhub（npm）
- **GitHub CLI**：GitHub 官方（apt）

请在使用前自行核对各组件 License；如用于企业/生产/商业环境，请完成合规审查。

---

## 📜 非商业说明

- 本仓库以学习与个人使用为目的进行容器打包集成。
- 不提供任何商业授权保证；对第三方组件许可的适配性不作承诺。

---

## 📚 文档

- `docs/BUILD.md`：构建与发布
- `docs/COMPONENTS.md`：组件清单
- `docs/TROUBLESHOOTING.md`：常见问题
