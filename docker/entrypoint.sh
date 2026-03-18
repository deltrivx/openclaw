#!/usr/bin/env bash
set -euo pipefail

if [[ "${PIPER_DISABLE:-0}" != "1" ]]; then
  uvicorn docker.openai_tts_server:app \
    --host "${PIPER_HOST:-127.0.0.1}" \
    --port "${PIPER_PORT:-18793}" \
    >/var/log/piper-openai.log 2>&1 &
fi

exec "$@"
