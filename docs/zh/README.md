# OpenClaw 中文使用说明

这个目录提供**中文使用指引**，目标是：

- 不修改上游 OpenClaw 源码
- 不破坏英文命令与参数兼容性
- 为中文用户补足部署、常用命令、TTS/OCR 说明

## 常用命令速查

- `openclaw onboard`：初始化向导
- `openclaw gateway start`：启动网关服务
- `openclaw gateway status`：查看网关状态
- `openclaw browser start`：启动浏览器
- `openclaw browser tabs`：查看浏览器标签页
- `openclaw cron list`：查看定时任务

## 推荐环境变量

```bash
TZ=Asia/Shanghai
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
```

## TTS

容器内默认提供 OpenAI 兼容 TTS：

- `http://127.0.0.1:18793/v1/audio/speech`
- 默认 voice：`zh_CN-huayan-medium`
- 默认格式：`mp3`

## OCR / PDF

镜像内置：

- `tesseract-ocr`
- `tesseract-ocr-chi-sim`
- `ocrmypdf`
- `poppler-utils`
