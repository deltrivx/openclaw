# 开箱即用增强版

面向“生产就绪”的一体化镜像：内置 Chromium、ffmpeg、faster‑whisper（仅二进制轮子）、Piper（中文女声 Huayan medium）、Tesseract OCR（中文简体）、OCRmyPDF（扫描 PDF → 可检索）、Poppler（pdftotext/渲染工具），并预装 ClawHub（技能包管理器）。

> 基于官方镜像 `ghcr.io/openclaw/openclaw:latest` 二次封装，专注“开箱即用 + 稳定构建 + 易部署”。

---

## ✨ 功能清单
- 浏览器与多媒体
  - Chromium（含驱动）、ffmpeg → 网页自动化 / 音视频处理即刻可用
- 语音链路
  - faster‑whisper（ASR）以 conda + pip **仅二进制轮子**安装，规避源码编译风险
  - Piper（TTS）采用 **OHF‑Voice/piper1‑gpl** manylinux wheel 安装，内置中文女声 **Huayan medium**（HuggingFace 多源回退）
- 本地 OCR 与 PDF 能力
  - Tesseract OCR + 中文简体语言包（chi_sim）
  - OCRmyPDF + Poppler：扫描 PDF → 可检索 PDF（保留版式），pdftotext 文本抽取
- 技能生态
  - ClawHub 预装（npm i -g clawhub），可直接搜索/安装多智能体/工具型技能
- 运行体验
  - 非交互 `openclaw` 调用修复（oc 包装），docker exec 下也能稳定执行

---

## 🚀 快速开始（docker‑compose）
保存为 `docker-compose.yml`：
```yaml
version: "3.9"

services:
  openclaw:
    image: ghcr.io/deltrivx/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    environment:
      TZ: "Asia/Shanghai"
      # 可选：ClawHub 自动登录（明文，建议后续改用 secrets）
      # CLAWHUB_TOKEN: "<你的_clawhub_token>"
    volumes:
      - /root/.openclaw:/root/.openclaw
      - /root/.openclaw:/root/.clawhub
    # 以环境变量自动写入 token（启用 CLAWHUB_TOKEN 后解注释）
    # command: >
    #   bash -lc '
    #   mkdir -p ~/.clawhub &&
    #   printf "%s" "$CLAWHUB_TOKEN" > ~/.clawhub/token && chmod 600 ~/.clawhub/token &&
    #   exec openclaw gateway start
    #   '
    ports:
      - "18789:18789"  # OpenClaw 网关端口（官方默认）
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

ClawHub（技能管理）
```bash
# 容器内（自动登录后可省略 login）
docker exec -it openclaw bash -lc 'clawhub --help && clawhub search "multi agent"'
# 安装技能（安装到挂载目录，持久化）
docker exec -it openclaw bash -lc 'cd /root/.openclaw && clawhub install multi-agent-roles --no-input'
```

OCR / PDF 工具
```bash
# Tesseract（中文+英文）
docker exec -it openclaw bash -lc 'tesseract /root/.openclaw/sample.jpg stdout -l chi_sim+eng --oem 1 --psm 6'

# OCRmyPDF（扫描PDF → 可检索PDF）
docker exec -it openclaw bash -lc 'ocrmypdf /root/.openclaw/in.pdf /root/.openclaw/out_ocr.pdf -l chi_sim+eng'

# pdftotext（原生文本PDF抽取，无OCR）
docker exec -it openclaw bash -lc 'pdftotext /root/.openclaw/in.pdf /root/.openclaw/out.txt'
```

---

## 🧩 组件版本与自检
```bash
# 浏览器
chromium --version && chromium-driver --version
# ASR / TTS
python -c "import faster_whisper,ctranslate2,tokenizers; print('asr ok')" && piper --help | head -n 1
# OCR / PDF
tesseract --version && ocrmypdf --version && pdftotext -v
# ClawHub
clawhub --help | head -n 1
```

---

## 🔧 设计与取舍
- 采用 conda+mamba + pip 二进制轮子，避免在 CI/buildx 下的源码编译不确定性
- Piper 走 manylinux wheel（OHF‑Voice/piper1‑gpl），Huayan 模型通过 HuggingFace 多源回退下载
- 保留 oc 包装，`docker exec <ctr> openclaw …` 在非交互场景可直接使用
- 版本号展示维持官方默认（括号可能仍为 unknown）；如需可读版本信息，建议在 README 或日志中引用镜像标签（日期/短 SHA）

---

## 🙏 致谢与来源（作者/版权归属）
- OpenClaw 核心项目与镜像：
  - 项目：https://github.com/openclaw/openclaw （原作者/贡献者）
  - 镜像：`ghcr.io/openclaw/openclaw`
- Piper（本地 TTS 引擎）：
  - rhasspy/piper（作者：Michael Hansen / Rhasspy 团队）：https://github.com/rhasspy/piper
  - OHF‑Voice/piper1‑gpl（作者：OHF‑Voice）：https://github.com/OHF-Voice/piper1-gpl
  - 中文女声 Huayan medium 模型：HuggingFace `rhasspy/piper-voices`：https://huggingface.co/rhasspy/piper-voices
- ASR：
  - faster‑whisper（SYSTRAN / Guillaume Klein 等）：https://github.com/SYSTRAN/faster-whisper
  - CTranslate2（OpenNMT）：https://github.com/OpenNMT/CTranslate2
  - tokenizers（Hugging Face）：https://github.com/huggingface/tokenizers
- PDF/OCR：
  - OCRmyPDF（作者：James R. Barlow）：https://github.com/ocrmypdf/OCRmyPDF
  - Poppler/Poppler-utils：XPDF/Poppler 项目
  - Tesseract OCR：Google/Tesseract 社区
- 技能生态：
  - ClawHub（CLI/Registry）：https://clawhub.com

> 上述开源项目与模型均归属于各自的原作者及社区，本文仅在工程层面进行整合与复用，**明确标注来源与作者**，并遵循各自许可证条款。

---

## ⚠️ 许可与使用声明（非商业）
- 本仓库以“仅供学习与研究”为目的发布，默认 **非商业使用**。
- 如需商用/再分发，请分别确认并遵循所有上游项目与模型的许可证（包括但不限于 OpenClaw、Piper/piper1‑gpl 及其模型、faster‑whisper/CTranslate2/tokenizers、OCRmyPDF/Poppler/Tesseract 等）。
- 如涉及商业化或内容安全，请自行进行合规审查与授权确认；本仓库作者不对因使用产生的合规/版权/内容风险承担责任。

---

## 🛠️ FAQ
- 端口/挂载：
  - 官方端口 `18789`；官方工作区 `/root/.openclaw`
  - Unraid 推荐挂载：`/mnt/user/appdata/openclaw:/root/.openclaw`
