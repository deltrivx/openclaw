#!/usr/bin/env bash
set -euo pipefail

# Start TTS server in background
node /app/tts-server.mjs &
TTS_PID=$!

# Start OpenClaw gateway (foreground)
# Keep args minimal; users can override CMD in docker run if needed.
node /app/openclaw.mjs gateway --allow-unconfigured

# If gateway exits, stop TTS
kill "$TTS_PID" 2>/dev/null || true
