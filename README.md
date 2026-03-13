# DeltrivX OpenClaw 容器镜像（增强版）

本仓库用于构建并发布镜像：

- 镜像名：`deltrivx/openclaw:latest`
- 上游基础镜像：`openclaw/openclaw:latest`
- 目标：**在不改变 OpenClaw 原有功能的基础上**，内置常用多媒体/浏览器/语音/OCR 工具链，开箱即用。

> 说明：本仓库仅提供容器镜像的“打包与集成”。OpenClaw 本体版权与商标归 OpenClaw 项目所有；其他第三方组件版权归各自作者所有。

---

## ✨ 内置能力一览

- Node.js 20+
- Chromium（用于浏览器自动化/网页渲染）
- Playwright 环境（含依赖）
- ffmpeg（音视频处理）
- faster-whisper（仅安装二进制 wheel：`faster-whisper` + `ctranslate2`）
- Piper TTS（内置二进制）
  - 中文女声：**Huayan medium**（`zh_CN-huayan-medium`）
- Tesseract OCR（含简体中文 `chi_sim`）
- OCRmyPDF（扫描 PDF → 可检索 PDF）
- Poppler（`pdftotext` 等 PDF 工具）
- ClawHub CLI（技能包管理器）
- GitHub CLI（`gh`）
- 修复容器中交互终端 `openclaw` 不生效的常见问题（引入 `tini` + 合理的 `TERM`）

---

## 🚀 快速开始

### 1) 拉取镜像

```bash
docker pull deltrivx/openclaw:latest
```

### 2) 运行（示例）

> 具体 OpenClaw 的运行参数/挂载目录/配置方式，以 OpenClaw 官方文档为准。

```bash
docker run --rm -it \
  --name openclaw \
  deltrivx/openclaw:latest
```

---

## 🧰 组件来源与版权声明（避免侵权）

本镜像集成了多个开源项目：

- **OpenClaw**：上游基础镜像 `openclaw/openclaw:latest`（来源：OpenClaw 官方仓库/镜像）
- **Chromium / Playwright**：Chromium 来自 Debian/Ubuntu 系统包；Playwright 来自 Microsoft Playwright 项目（npm 包）
- **ffmpeg**：来自 Debian/Ubuntu 系统包（FFmpeg 项目）
- **faster-whisper / ctranslate2**：来自 PyPI 二进制 wheel（原作者项目）
- **Piper**：二进制来自 rhasspy/piper GitHub Releases
- **Huayan (zh_CN-huayan-medium) 语音模型**：来自 rhasspy/piper-voices Releases
- **Tesseract OCR**：来自 Debian/Ubuntu 系统包（Tesseract 项目）
- **OCRmyPDF**：来自 Debian/Ubuntu 系统包（OCRmyPDF 项目）
- **Poppler**：来自 Debian/Ubuntu 系统包（Poppler 项目）
- **ClawHub CLI**：npm 包（clawhub）
- **GitHub CLI (gh)**：GitHub 官方 apt 源

如需在企业/生产环境使用，请务必自行复核各组件 License 及其依赖的许可条款。

---

## 📜 非商业说明

- 本仓库的目标是**学习与个人使用**的容器打包集成。
- **不提供任何商业授权保证**；也不对第三方组件许可的适配性作出承诺。
- 若你计划将该镜像用于商业用途，请自行进行 License 合规审查。

---

## 🔄 上游自动同步（镜像更新）

仓库包含 GitHub Actions：

- 定时拉取上游 `openclaw/openclaw:latest` 的更新
- 触发镜像重新构建
- 推送到 Docker Hub：`deltrivx/openclaw:latest`

详见：`.github/workflows/sync-upstream.yml`

---

## 🏗️ 本地构建

```bash
docker build -t deltrivx/openclaw:latest .
```

---

## 📚 文档

- `docs/BUILD.md`：构建与发布说明
- `docs/COMPONENTS.md`：组件清单、版本与来源
- `docs/TROUBLESHOOTING.md`：常见问题（含 openclaw 终端交互）

