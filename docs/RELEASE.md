# 发布与同步（Release / Sync）

你已确认：
- 以 `openclaw/openclaw:latest` 为上游基础镜像
- Node 跟随并确保为 20+（Dockerfile 中已做校验/安装）
- `rhasspy/piper-voices` 使用 `latest release` 直链：OK

---

## 目标

- Docker Hub 镜像：`deltrivx/openclaw:latest`
- GitHub 仓库：`https://github.com/deltrivx/openclaw`
- 上游：`openclaw/openclaw:latest`

---

## 你需要配置的 GitHub Secrets

在仓库 Settings → Secrets and variables → Actions → **New repository secret**：

- `DOCKERHUB_USERNAME`：你的 Docker Hub 用户名
- `DOCKERHUB_TOKEN`：你的 Docker Hub Access Token（建议专用 token）

---

## 自动同步策略

本仓库 workflow：`.github/workflows/sync-upstream.yml`

触发方式：
- 定时：每天 03:30 UTC（可自行修改）
- 手动：workflow_dispatch

行为：
- 直接构建当前仓库的 Dockerfile
- push `deltrivx/openclaw:latest`

> 说明：这里的“同步上游更新”体现在：每次构建都会拉取 `openclaw/openclaw:latest` 的最新层并重新打包。

---

## 建议的标签策略（可选）

目前只推 `latest`，简单但不可追溯。

如需可追溯性，可追加：
- `latest`
- `sha-<GITHUB_SHA>`
- `date-YYYYMMDD`

之后我可以按你的偏好把 workflow 改成多标签推送。

---

## 合规提示

镜像中集成多个开源组件：请在 README 的“来源与版权声明”中保留作者与项目来源描述；商用前请自行做 License 合规审查。
