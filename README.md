# DeltrivX OpenClaw 增强版镜像（中文浏览器环境 / All‑in‑One 工具链容器）

- 镜像：`deltrivx/openclaw:latest`
- 上游基础镜像：`ghcr.io/openclaw/openclaw:latest`
- 目标：在 **不改变 OpenClaw 原有功能** 的前提下，内置浏览器自动化 / 音视频 / 语音 / OCR / PDF 工具链。

> 说明：本仓库仅做“打包与集成”。OpenClaw 版权与商标归 OpenClaw 项目所有；第三方组件版权归各自作者所有。

---

## ✨ 内置能力（按当前构建目标）

### 1) 镜像构建/同步
- 上游基础：`ghcr.io/openclaw/openclaw:latest`
- GitHub Actions：自动构建并推送 `deltrivx/openclaw:latest`

### 2) 浏览器自动化（真实浏览器，不走 mShots）
- Node Playwright：全局安装，可 `require('playwright')`
- Playwright Chromium：已内置，浏览器目录：`/ms-playwright`
- 兼容其它程序调用：提供稳定路径（软链到 Playwright Chromium）：
  - `/usr/bin/chromium`
- 中文环境：镜像默认设置 `LANG/LC_ALL=zh_CN.UTF-8`，并安装 `fonts-noto-cjk`；
  Playwright 侧如需更强一致性，建议启动时附加：`--lang=zh-CN`、`--accept-lang=zh-CN,zh`。

### 3) 多媒体/音视频
- ffmpeg

### 4) OCR / PDF
- Tesseract OCR（含简体中文 `chi_sim`）
- OCRmyPDF
- Poppler（`pdftotext` 等）

### 5) 语音/转写
- edge-tts（Python 包）
- faster‑whisper + ctranslate2（Python 包，优先二进制 wheel 安装）

### 6) 工具链
- ClawHub CLI
- GitHub CLI（`gh`）
- PyYAML（`pyyaml`）

### 7) Skills 安装目录约定
- 约定路径：`/root/.agents/skills/`

---

## ✅ 自检

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

---

## 🧾 来源与版权声明（避免侵权）

- OpenClaw：基础镜像 `ghcr.io/openclaw/openclaw:latest`
- Playwright：Microsoft Playwright（npm / PyPI）
- Playwright Chromium：由 Playwright 官方分发的浏览器构建（`playwright install chromium`）
- ffmpeg：FFmpeg 项目
- Piper：rhasspy/piper（二进制）
- Huayan voice model：rhasspy/piper-voices（若 latest 缺失则使用公开镜像源）
- Tesseract / OCRmyPDF / Poppler：各自开源项目

---

## 📜 非商业说明

- 以学习与个人使用为目的进行容器打包集成。
- 不提供商业授权保证；商用前请自行完成 License 合规审查。
