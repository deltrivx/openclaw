# deltrivx/openclaw — 一站式开箱即用容器

基于上游镜像 `ghcr.io/openclaw/openclaw:latest`，集成：

- 内置 Chromium（含驱动）用于网页自动化/无头浏览器
- 内置 ffmpeg（音视频处理）
- 内置 faster-whisper（离线语音识别，Python 版）
- 内置 Piper + 中文女声模型「Huayan medium」（离线 TTS，中文女声，直接可用）
- 修复容器后台 `docker exec <ctr> openclaw ...` 无效的问题（非交互/后台可直接调用）
- 支持启动时自动与上游同步更新（保持实时跟进上游改动，可开关）

适用于需要「一条命令起容器，立即具备浏览器 + ASR + TTS + ffmpeg」的场景。

> 致谢与来源：本项目基于并尊重上游开源项目 [openclaw/openclaw](https://github.com/openclaw/openclaw)。核心运行时镜像来自 `ghcr.io/openclaw/openclaw:latest`。本仓库仅做增量集成与工程化封装，遵循上游许可证与声明。

---

## 快速开始

```bash
# 1) 构建镜像
# 仓库：deltrivx/openclaw
# 标签：latest（或自定义）
docker build -t deltrivx/openclaw:latest .

# 2) 运行（示例，按需暴露端口/挂载数据）
docker run -d \
  --name openclaw \
  --restart unless-stopped \
  -e OPENCLAW_AUTO_UPDATE=true \
  -p 3000:3000 -p 8080:8080 \
  deltrivx/openclaw:latest

# 3) 验证 CLI 可用性（非交互/后台同样有效）
docker exec -it openclaw openclaw --version
# 或
docker exec -it openclaw oc --version
```

- 默认入口将启动 OpenClaw Gateway；如需执行其他命令，可在 `docker run` 后附加命令覆盖。
- 提供 `oc` 与 `openclaw-cli` 软链接，保证在非交互 `exec` 场景也能正确寻址并执行。

---

## 组件说明

- Chromium：通过系统包安装（含 `chromium-driver`），环境变量 `CHROME_PATH=/usr/bin/chromium`。
- ffmpeg：系统包内置。
- faster-whisper：Python 包，版本 `1.0.3`，适合 CPU/GPU 推理，按需配置模型下载目录。
- Piper：二进制放置于 `/opt/piper`，并链接 `piper` 到 PATH。
  - 已预置中文女声模型：`/opt/piper/models/zh-CN-huayan-medium.onnx`（及 `.onnx.json` 配置）
  - 示例调用：
    ```bash
    echo "你好，世界" | piper -m /opt/piper/models/zh-CN-huayan-medium.onnx -f out.wav
    ```
- Auto Update：容器启动时可自动调用 `openclaw gateway update` 与上游同步（默认开启，可通过 `OPENCLAW_AUTO_UPDATE=false` 关闭）。

---

## 使用示例

- 启动并查看日志：
  ```bash
  docker logs -f openclaw
  ```

- 手动运行某个子命令（非交互）：
  ```bash
  docker exec openclaw openclaw status
  docker exec openclaw openclaw gateway restart
  ```

- 使用 Piper 生成中文女声音频：
  ```bash
  docker exec -i openclaw bash -lc 'echo "本宫测试一下合成语音。" | \
    piper -m /opt/piper/models/zh-CN-huayan-medium.onnx -f /data/tts.wav'
  ```

- 使用 faster-whisper 做离线识别：
  ```bash
  docker exec -it openclaw python3 - <<'PY'
  from faster_whisper import WhisperModel
  model = WhisperModel("medium", device="auto")
  segments, info = model.transcribe("/data/sample.wav", beam_size=5)
  for s in segments:
      print(f"[{s.start:.2f}->{s.end:.2f}] {s.text}")
  PY
  ```

---

## 常见问题（FAQ）

- Q: 为什么我在后台/非交互 `docker exec` 时找不到 `openclaw`？
  - A: 本镜像已通过入口与 `oc` 包装脚本修复此问题，确保 PATH 与 shell 环境一致，非交互场景同样可用。

- Q: 如何关闭启动时的上游自动更新？
  - A: 运行时设置 `-e OPENCLAW_AUTO_UPDATE=false` 即可。

- Q: Piper 模型能否替换为其他中文音色？
  - A: 可以。将其他模型放入 `/opt/piper/models/` 并在调用时指定 `-m` 路径即可。

---

## 许可证与声明

- 上游项目：`openclaw/openclaw`（镜像来源：`ghcr.io/openclaw/openclaw:latest`）
- 本仓库仅做集成与工程化封装，遵循上游许可证。
- 文字、脚本与构建文件中均已标注来源并致谢原作者。

---

## 目录结构

```
.
├─ Dockerfile
├─ entrypoint.sh
├─ scripts/
│  └─ fix_openclaw_exec.sh
└─ README.cn.md
```
