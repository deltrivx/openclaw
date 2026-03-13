# 构建与发布说明

目标镜像：`deltrivx/openclaw:latest`

## 本地构建

```bash
docker build -t deltrivx/openclaw:latest .
```

## 运行自检（建议）

进入容器后建议检查：

```bash
node -v
chromium --version
ffmpeg -version
python3 -c "import faster_whisper; print('faster-whisper OK')"
/opt/piper/piper --help | head
tesseract --version
ocrmypdf --version
pdftotext -v 2>&1 | head
openclaw --help | head
```

## 发布（由你手动）

你说你会自己提交上传到 GitHub 并发布镜像；因此本仓库只提供：

- Dockerfile
- CI workflow
- 文档

你需要准备：

- Docker Hub 凭据（GitHub Actions Secrets）
  - `DOCKERHUB_USERNAME`
  - `DOCKERHUB_TOKEN`

