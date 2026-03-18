#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '%s %s\n' "[entrypoint]" "$*"
}

# Ensure skills dir exists (repo README expectation)
mkdir -p /root/.agents/skills

# Best-effort: also expose workspace skills under /root/.agents/skills/workspace if mounted
if [ -d /root/.openclaw/workspace/skills ] && [ ! -e /root/.agents/skills/workspace ]; then
  ln -s /root/.openclaw/workspace/skills /root/.agents/skills/workspace || true
fi

# Quick capability checks (helps debugging images)
for bin in openclaw clawhub bun node python3 ffmpeg chromium tesseract ocrmypdf pdftotext; do
  if command -v "$bin" >/dev/null 2>&1; then
    log "$bin: $(command -v "$bin")"
  else
    log "$bin: MISSING"
  fi
done

# Start TTS server in background
node /app/tts-server.mjs &
TTS_PID=$!

# Start OpenClaw gateway (foreground)
# Keep args minimal; users can override CMD in docker run if needed.
node /app/openclaw.mjs gateway --allow-unconfigured

# If gateway exits, stop TTS
kill "$TTS_PID" 2>/dev/null || true
