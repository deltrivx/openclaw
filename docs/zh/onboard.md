# OpenClaw Onboard（初始化向导）中文“逐步对照”

> 目标：把 `openclaw onboard` 首次初始化这条链路，用中文说明“每一步在干什么、该填什么、常见坑是什么”，做到**照着走就能完成**。
>
> 说明：上游交互界面仍以英文为主；本页提供“中文对照 + 推荐选项 + 排障”。

---

## 0) 启动前准备（强烈建议）

### 0.1 Docker 环境变量（中文/时区）

```bash
TZ=Asia/Shanghai
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
```

### 0.2 推荐的挂载（避免向导做完就丢）

至少挂载两处：
- `/root/.openclaw`：配置、凭据、渠道会话等
- `/root/.openclaw/workspace`：你的工作区（记忆/文件/技能等）

（仓库 README 里有 docker-compose 示例）

---

## 1) 进入向导

```bash
openclaw onboard
# 或（本仓库提供的中文辅助 wrapper，如果你启用了）
openclaw-zh onboard
```

向导通常会覆盖这些主题：
- 网关（Gateway）：启动方式、监听地址、访问方式
- 工作区（Workspace）：文件/技能/记忆的默认目录
- 渠道（Channel）：Discord/Telegram/QQBot 等接入
- 技能（Skills）：安装/启用与密钥

---

## 2) 关键选项解释（你会在向导里反复遇到的概念）

### 2.1 Workspace（工作区）
**是什么：** 你和助手共享的“长期目录”。

**推荐：**
- Docker：把 workspace 挂载到宿主机路径，避免容器重建丢数据
- 如果你不确定填什么：先用默认值，跑通后再迁移

### 2.2 Gateway（网关）
**是什么：** OpenClaw 的常驻后台进程（收消息、调度工具、管理浏览器/音频等）。

**推荐：**
- 生产：后台运行 + `restart: unless-stopped`
- 远程访问：优先走 **Tailscale serve**（更安全，也更省事）

### 2.3 Credentials / Secrets（密钥）
向导可能会问你“密钥输入模式”或引用方式。

- `--secret-input-mode plaintext`：直接输入字符串（最简单）
- `--secret-input-mode ref`：引用已保存的 secret（更安全，适合重复部署）

> 如果你看到报错：`Invalid --secret-input-mode`，说明值只能是 `plaintext` 或 `ref`。

### 2.4 Reset（重置）
你可能会用到：
- `--reset`：重置
- `--reset-scope`：重置范围（常见：`config`、`config+creds+sessions`、`full`）

> 如果你看到报错：`Invalid --reset-scope`，说明 scope 写错了。

---

## 3) 常见报错与排障（高频）

### 3.1 非交互式模式需要显式确认风险
如果你跑：

```bash
openclaw onboard --non-interactive
```

可能会报：需要 `--accept-risk`。

**解决：**
```bash
openclaw onboard --non-interactive --accept-risk ...
```

### 3.2 Auth choice 已弃用 / 旧选项兼容
如果你看到类似“认证方式已弃用”的提示，按提示改用推荐的 `--auth-choice token` 或 `--auth-choice openai-codex`。

### 3.3 Docker/Unraid + 代理导致 Tailscale 不稳定（重要）
如果你需要外网代理，务必理解：
- OpenClaw 容器里跑 tailscaled 用于 `tailscale serve`
- **tailscaled 不建议走 HTTP(S)_PROXY/ALL_PROXY**，否则容易 `unexpected EOF / hostname mismatch`

本仓库镜像已做修复：**仅对 tailscaled 进程禁用代理环境变量**（详见 README 里的 Tailscale 说明段）。

### 3.4 QQBot / Discord 等长连接偶发断线
看到 `WebSocket closed: 1006/4009` 这类错误，多数情况下会自动重连恢复。若频繁发生，再针对具体 channel 做稳定性排查。

---

## 4) 完成向导后的“验收清单”（建议照着查一遍）

1) 网关是否在监听：
- `openclaw gateway status`

2) 浏览器组件是否正常（需要浏览器自动化时）：
- `openclaw browser start`
- `openclaw browser status`

3) Dashboard 访问是否正常（如启用）：
- 优先用 Tailscale serve 的 URL

4) 渠道是否连通：
- 发送一条测试消息，看能否进/出

---

## 5) 我需要你提供什么，才能把本文档补到“逐题逐项一一对应”

把你运行 `openclaw onboard` 时看到的 **每一屏英文提示**（或截图）发我 3–5 张，我会：
- 把每个问题逐条翻译
- 给出“推荐选项”和选择理由
- 加入对应的错误示例与修复办法
