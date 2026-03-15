# syntax=docker/dockerfile:1.7

# Enhanced runtime image based on upstream OpenClaw.
# Goal: Docker-friendly, batteries-included (chromium+playwright, ffmpeg, OCR, piper TTS, venv python tools)

FROM ghcr.io/openclaw/openclaw:latest

# Upstream image defaults to non-root (node). Package installs require root.
USER root

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

# ---- Environment defaults ----
# Skills/agents
ENV OPENCLAW_AGENT_DIR=/root/.agents \
    CLAWHUB_WORKDIR=/root/.agents \
    OPENCLAW_SKILLS_DIR=/root/.agents/skills \
    # Python venv
    VENV_PATH=/opt/venv \
    PATH=/opt/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    # Browser
    CHROME_PATH=/usr/bin/chromium

# ---- System packages ----
# chromium + deps, fonts (CJK), multimedia, OCR/PDF utilities, python3 + venv
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl wget unzip xz-utils \
      chromium \
      # Chromium runtime deps (keep explicit for stability across base updates)
      libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libdrm2 libgbm1 libnspr4 libnss3 \
      libx11-xcb1 libxcomposite1 libxdamage1 libxfixes3 libxkbcommon0 libxrandr2 \
      libpango-1.0-0 libcairo2 libpangocairo-1.0-0 \
      fonts-noto-cjk fonts-noto-color-emoji \
      ffmpeg \
      tesseract-ocr tesseract-ocr-chi-sim \
      ocrmypdf poppler-utils \
      python3 python3-venv \
 && rm -rf /var/lib/apt/lists/*

# ---- Python venv ----
# Keep system python at /usr/bin/python3, but prefer venv via PATH.
RUN python3 -m venv "$VENV_PATH" \
 && "$VENV_PATH/bin/pip" install --no-cache-dir --upgrade pip setuptools wheel

# ---- Piper (offline TTS) + voice model baked in ----
# Piper binary (x86_64) from rhasspy/piper release.
ARG PIPER_VERSION=2023.11.14-2
RUN mkdir -p /opt/piper/bin \
 && curl -fsSL -o /tmp/piper.tar.gz "https://github.com/rhasspy/piper/releases/download/${PIPER_VERSION}/piper_linux_x86_64.tar.gz" \
 && tar -xzf /tmp/piper.tar.gz -C /opt/piper/bin --strip-components=1 \
 && rm -f /tmp/piper.tar.gz \
 && ln -sf /opt/piper/bin/piper /usr/local/bin/piper

# Huayan medium model from the canonical voices repo.
# Reference: https://huggingface.co/rhasspy/piper-voices (voices.json)
ARG PIPER_VOICE_BASE_URL=https://huggingface.co/rhasspy/piper-voices/resolve/main
RUN mkdir -p /opt/piper/models \
 && curl -fsSL -o /opt/piper/models/zh_CN-huayan-medium.onnx \
      "$PIPER_VOICE_BASE_URL/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx" \
 && curl -fsSL -o /opt/piper/models/zh_CN-huayan-medium.onnx.json \
      "$PIPER_VOICE_BASE_URL/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx.json"

# Simple offline TTS wrapper: text -> wav
RUN cat > /usr/local/bin/piper-tts <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   echo "你好" | piper-tts /tmp/out.wav
#   piper-tts /tmp/out.wav <<<"你好"

OUT_PATH="${1:-}"
if [[ -z "${OUT_PATH}" ]]; then
  echo "usage: piper-tts <out.wav>" >&2
  exit 2
fi

MODEL="/opt/piper/models/zh_CN-huayan-medium.onnx"
CONFIG="/opt/piper/models/zh_CN-huayan-medium.onnx.json"

/usr/local/bin/piper \
  --model "$MODEL" \
  --config "$CONFIG" \
  --output_file "$OUT_PATH"
EOF
RUN chmod +x /usr/local/bin/piper-tts

# ---- Patch QQBot extension: enable local (offline) TTS via piper when API TTS is not configured ----
# Unraid typically bind-mounts /root/.openclaw, so we patch the mounted extension at container start.
RUN cat > /usr/local/bin/openclaw-entrypoint <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

QQBOT_EXT_DIR="/root/.openclaw/extensions/openclaw-qqbot"
MARKER="$QQBOT_EXT_DIR/.local-tts-patched.v1"

patch_qqbot() {
  local audio_js="$QQBOT_EXT_DIR/dist/src/utils/audio-convert.js"
  local gateway_js="$QQBOT_EXT_DIR/dist/src/gateway.js"

  [[ -f "$audio_js" ]] || return 0
  [[ -f "$gateway_js" ]] || return 0

  # 1) Add localTextToSilk() helper export (idempotent)
  if ! grep -q "export async function localTextToSilk" "$audio_js"; then
    cat >> "$audio_js" <<'JS'

// ---- OpenClaw QQBot local/offline TTS (piper) ----
// If channels.qqbot.tts is not configured, fall back to piper to generate a WAV,
// then use existing ffmpeg/wasm pipeline to encode SILK for QQ upload.
export async function localTextToSilk(text, outputDir) {
  const outDir = outputDir || "/tmp/openclaw/qqbot-tts";
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

  const wavPath = path.join(outDir, `piper-${Date.now()}.wav`);

  // Prefer our wrapper if present; otherwise call piper directly.
  const wrapper = "/usr/local/bin/piper-tts";
  try {
    await new Promise((resolve, reject) => {
      const child = execFile(wrapper, [wavPath], { timeout: 120000 }, (err) => (err ? reject(err) : resolve()));
      child.stdin?.end(text);
    });
  } catch (e) {
    const model = process.env.PIPER_MODEL || "/opt/piper/models/zh_CN-huayan-medium.onnx";
    const config = process.env.PIPER_CONFIG || "/opt/piper/models/zh_CN-huayan-medium.onnx.json";
    await new Promise((resolve, reject) => {
      const child = execFile("/usr/local/bin/piper", ["--model", model, "--config", config, "--output_file", wavPath], { timeout: 120000 }, (err) => (err ? reject(err) : resolve()));
      child.stdin?.end(text);
    });
  }

  if (!fs.existsSync(wavPath)) throw new Error(`local TTS failed: wav not created: ${wavPath}`);
  const stat = fs.statSync(wavPath);
  if (stat.size <= 44) throw new Error(`local TTS failed: wav empty: ${wavPath}`);

  const targetRate = 24000;
  const ffmpegCmd = await checkFfmpeg();
  if (ffmpegCmd) {
    const pcmBuf = await ffmpegToPCM(ffmpegCmd, wavPath, targetRate);
    if (!pcmBuf || pcmBuf.length === 0) throw new Error("local TTS: ffmpeg produced empty PCM");
    const { silkBuffer, duration } = await pcmToSilk(pcmBuf, targetRate);
    const silkPath = path.join(outDir, `tts-${Date.now()}.silk`);
    fs.writeFileSync(silkPath, silkBuffer);
    return { silkPath, silkBase64: silkBuffer.toString("base64"), duration };
  }

  const wavBuf = fs.readFileSync(wavPath);
  const wavInfo = parseWavFallback(wavBuf);
  if (!wavInfo) throw new Error("local TTS: WAV parse failed (no ffmpeg available)");
  const { silkBuffer, duration } = await pcmToSilk(wavInfo, targetRate);
  const silkPath = path.join(outDir, `tts-${Date.now()}.silk`);
  fs.writeFileSync(silkPath, silkBuffer);
  return { silkPath, silkBase64: silkBuffer.toString("base64"), duration };
}
JS
  fi

  # 2) Ensure gateway imports localTextToSilk (idempotent)
  if grep -q "from \"\./utils/audio-convert\.js\"" "$gateway_js" && ! grep -q "localTextToSilk" "$gateway_js"; then
    sed -i 's/{ \(.*\)textToSilk\(.*\) } from "\.\/utils\/audio-convert\.js"/{ \1textToSilk, localTextToSilk\2 } from "\.\/utils\/audio-convert\.js"/g' "$gateway_js" || true
  fi

  # 3) Replace the "TTS not configured" hard-fail with localTextToSilk fallback
  GATEWAY_JS="$gateway_js" node - <<'NODE'
const fs = require('fs');
const gateway = process.env.GATEWAY_JS;
let s = fs.readFileSync(gateway, 'utf8');
const needle = "const ttsCfg = resolveTTSConfig(cfg);\n                            if (!ttsCfg) {\n                              log?.error(`[qqbot:${account.accountId}] TTS not configured (channels.qqbot.tts in openclaw.json)`);\n                              await sendErrorMessage(`[QQBot] TTS 未配置，请在 openclaw.json 的 channels.qqbot.tts 中配置`);\n                            } else {";
if (s.includes(needle)) {
  const replacement = "const ttsCfg = resolveTTSConfig(cfg);\n                            if (!ttsCfg) {\n                              log?.warn?.(`[qqbot:${account.accountId}] TTS not configured; falling back to local piper TTS`);\n                              const ttsDir = getQQBotDataDir(\"tts\");\n                              const { silkPath, silkBase64, duration } = await localTextToSilk(ttsText, ttsDir);\n                              log?.info(`[qqbot:${account.accountId}] Local TTS done: ${formatDuration(duration)}, file saved: ${silkPath}`);\n                              await sendWithTokenRetry(async (token) => {\n                                if (event.type === \"c2c\") {\n                                  await sendC2CVoiceMessage(token, event.senderId, silkBase64, event.messageId, ttsText, silkPath);\n                                } else if (event.type === \"group\" && event.groupOpenid) {\n                                  await sendGroupVoiceMessage(token, event.groupOpenid, silkBase64, event.messageId);\n                                } else if (event.channelId) {\n                                  await sendChannelMessage(token, event.channelId, `[语音消息暂不支持频道发送] ${ttsText}`, event.messageId);\n                                }\n                              });\n                              log?.info(`[qqbot:${account.accountId}] Voice message sent (local TTS)`);\n                            } else {";
  s = s.replace(needle, replacement);
  fs.writeFileSync(gateway, s);
}
NODE

  date > "$MARKER"
}

if [[ -d "$QQBOT_EXT_DIR" ]] && [[ ! -f "$MARKER" ]]; then
  patch_qqbot || true
fi

exec openclaw gateway run --allow-unconfigured
EOF
RUN chmod +x /usr/local/bin/openclaw-entrypoint

# ---- OpenClaw Gateway in Docker: run foreground by default ----
# (Service-based start is often unavailable in containers.)
EXPOSE 19000

# Runtime as root (requested for Unraid volume mappings using /root/.openclaw).
ENTRYPOINT ["/usr/local/bin/openclaw-entrypoint"]
