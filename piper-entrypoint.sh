#!/usr/bin/env bash
set -euo pipefail

# Start Piper OpenAI-compatible server (optional)
# If it fails, we still want OpenClaw to start.
if command -v python3 >/dev/null 2>&1; then
  (python3 /usr/local/bin/openai_tts_server.py \
    --host 127.0.0.1 \
    --port 18793 \
    --models-dir "${PIPER_MODELS_DIR:-/opt/piper/models}" \
    --voice "${PIPER_VOICE:-zh_CN-huayan-medium}" \
    >/var/log/piper-tts.log 2>&1 &) || true
fi

exec "$@"
