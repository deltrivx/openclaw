#!/usr/bin/env bash
set -euo pipefail

if [[ "${PIPER_DISABLE:-0}" != "1" ]]; then
  openedai-speech \
    --host "${PIPER_HOST:-127.0.0.1}" \
    --port "${PIPER_PORT:-18793}" \
    --piper \
    --piper-voice "${PIPER_MODELS_DIR:-/opt/piper/models}/${PIPER_VOICE:-zh_CN-huayan-medium}.onnx" \
    --piper-config "${PIPER_MODELS_DIR:-/opt/piper/models}/${PIPER_VOICE:-zh_CN-huayan-medium}.onnx.json" \
    --output-format mp3 \
    >/var/log/piper-openai.log 2>&1 &
fi

exec "$@"
