#!/usr/bin/env bash
set -euo pipefail
# Ensure openclaw is resolvable both interactively and via docker exec
if command -v openclaw >/dev/null 2>&1; then
  exit 0
fi
if command -v npx >/dev/null 2>&1; then
  ln -sf "$(command -v npx)" /usr/local/bin/openclaw
fi
