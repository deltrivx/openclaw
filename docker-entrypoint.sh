#!/usr/bin/env bash
set -euo pipefail

# OpenClaw container entrypoint
# Goal: keep gateway up even if config is invalid by attempting an automatic doctor --fix.

CONFIG_FILE="/root/.openclaw/openclaw.json"
STAMP_FILE="/tmp/openclaw-doctor-fix.stamp"

run_fix() {
  echo "[entrypoint] running: openclaw doctor --fix"
  if command -v timeout >/dev/null 2>&1; then
    # Avoid wedging the container on a hung doctor.
    timeout 120s openclaw doctor --fix || true
  else
    openclaw doctor --fix || true
  fi
}

# Run at most once per container boot.
if [[ -f "$CONFIG_FILE" ]] && [[ ! -f "$STAMP_FILE" ]]; then
  touch "$STAMP_FILE" || true
  run_fix
fi

# Start gateway (preserve upstream behavior)
exec node openclaw.mjs gateway --allow-unconfigured
