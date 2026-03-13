# 常见问题排查

## 1. 容器内 `openclaw` 交互终端不生效/信号异常

常见表现：
- `openclaw` 启动后 Ctrl+C 不生效
- 子进程信号无法正确传递
- 交互式终端显示/输入异常

本镜像的处理：
- 使用 `tini` 作为 PID1，负责信号转发与进程回收
- 设置 `TERM=xterm-256color`

你也可以用如下方式运行（确保分配 TTY）：

```bash
docker run --rm -it deltrivx/openclaw:latest
```

## 2. Playwright/Chromium 依赖缺失

如遇到 Chromium 启动报缺库：
- 检查 Dockerfile 是否成功安装 `npx playwright install-deps`
- 检查容器是否基于 Debian/Ubuntu（apt 可用）

## 3. faster-whisper 仅二进制 wheel 安装失败

本镜像使用：

```bash
pip install --only-binary=:all: faster-whisper ctranslate2
```

如果你的平台架构不是 x86_64（例如 arm64），可能没有对应 wheel，需要调整策略。

## 4. OCRmyPDF 处理中文

Tesseract 简体中文语言包为：

- `chi_sim`

示例：

```bash
ocrmypdf -l chi_sim input.pdf output.pdf
```

