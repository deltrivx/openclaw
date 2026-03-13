# 组件清单（含来源声明）

> 版本可能随 `latest` 与系统包更新而变化；以最终构建日志为准。

## 上游

- OpenClaw 基础镜像：`openclaw/openclaw:latest`

## 浏览器与自动化

- Chromium：系统包（Debian/Ubuntu apt）
- Playwright：npm 包（Microsoft Playwright）

## 多媒体

- ffmpeg：系统包（FFmpeg 项目）

## 语音

- faster-whisper：PyPI 二进制 wheel（作者项目）
- ctranslate2：PyPI 二进制 wheel（作者项目）
- Piper：rhasspy/piper Releases（二进制）
- Huayan medium 中文女声：rhasspy/piper-voices Releases（模型文件）

## OCR / PDF

- Tesseract：系统包（Tesseract 项目）
  - 语言包：`tesseract-ocr-chi-sim`
- OCRmyPDF：系统包（OCRmyPDF 项目）
- Poppler：系统包（Poppler 项目；`pdftotext` 等）

## 工具

- ClawHub CLI：npm 包 `clawhub`
- GitHub CLI：GitHub 官方 apt 源（`gh`）

