# OpenClaw 中文增强落地清单（首版）

## 目标

在不违背既定规则的前提下，为 `deltrivx/openclaw` 建立中文增强版基础：

- 不开本地功能分支
- 不本地构建
- 不提 PR
- 云端构建并推送 GHCR
- 直接提交到 GitHub
- 优先完成 Web UI / onboard / CLI 的中文化

## 已确认事实

1. 上游仓库 `openclaw/openclaw` 已存在前端 i18n 基础：
   - `ui/src/i18n/locales/en.ts`
   - `ui/src/i18n/locales/zh-CN.ts`
   - `ui/src/i18n/locales/zh-TW.ts`
2. 上游已存在 CLI/onboard 相关源码与可改造入口：
   - `src/commands/onboard*.ts`
   - `src/cli/program/register.onboard.ts`
3. 上游已存在中文文档目录：
   - `docs/zh-CN/*`
4. `ui` 当前 `zh-CN` 覆盖度较高，但仍缺少 4 个 key：
   - `theme`
   - `toolCallsToggle`
   - `lastRun`
   - `reset`

## 推荐实施顺序

### Phase 1：恢复源码仓库结构

- 引入上游完整源码到当前仓库
- 以当前仓库 README 为增强版入口文档
- 后续再基于完整源码进行中文增强与镜像增强

### Phase 2：优先完成中文化

#### Web UI / Dashboard
- 补齐 `ui/src/i18n/locales/zh-CN.ts` 缺失键
- 检查 locale 默认策略
- 保证缺失键回退英文，不影响运行

#### CLI / onboard
- 盘点 `src/commands/onboard*.ts` 中写死的英文提示
- 优先改造：
  - `openclaw onboard`
  - `openclaw help`
  - 配置引导与常见提示
- 尽量复用上游 i18n，而不是粗暴全文替换

#### 文档
- README 增加中文增强说明
- 给出一键汉化说明
- 给出 GHCR 拉取和使用方式

### Phase 3：恢复云端构建

- 新建 `.github/workflows/build-ghcr.yml`
- 触发：`push` 到 `main` + `workflow_dispatch`
- 推送镜像：`ghcr.io/deltrivx/openclaw:latest`
- 使用已配置好的 `GHCR_TOKEN`

### Phase 4：后续功能增强（汉化完成后）

- Chromium
- ffmpeg
- OCR / Tesseract / OCRmyPDF / Poppler
- Piper TTS
- 其他 README 中已描述的增强项

## 首批提交建议

第一批提交优先包含：

1. 上游源码基线导入
2. `README.md` 改为中文增强版定位
3. `ui/src/i18n/locales/zh-CN.ts` 缺失键补齐
4. 新建 `docs/zh-CN/customization.md`
5. 新建 `.github/workflows/build-ghcr.yml`

## 暂不做

- 本地构建验证
- 本地分支开发
- PR 流程
- 大规模功能增强

## 提交策略

- 直接提交到 GitHub 仓库 `deltrivx/openclaw`
- 使用 `main` 直推
- 由 GitHub Actions 云端完成后续镜像构建
