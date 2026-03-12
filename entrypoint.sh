#!/usr/bin/env bash
set -euo pipefail

# Respect upstream environment, but allow our tweaks
: "${OPENCLAW_AUTO_UPDATE:=true}"
: "${OPENCLAW_UPDATE_CHANNEL:=stable}"

# Workaround: make sure npm/npx shims and PATH are available under PID1
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"

# Fix: allow `docker exec <container> openclaw ...` to work non-interactively
# We add a shim that resolves npx shims and bash -lc search path
if ! command -v openclaw >/dev/null 2>&1; then
  if command -v npx >/dev/null 2>&1; then
    ln -sf "$(command -v npx)" /usr/local/bin/openclaw || true
  fi
fi

# Optional auto-update to sync upstream on container start
if [[ "${OPENCLAW_AUTO_UPDATE}" == "true" ]]; then
  echo "[entrypoint] Auto-updating OpenClaw (channel=${OPENCLAW_UPDATE_CHANNEL})..."
  if command -v openclaw >/dev/null 2>&1; then
    openclaw gateway update || true
  fi
fi

# Print versions for diagnostics
node -v || true
npm -v || true
openclaw --version || true

# If called with a CLI subcommand, run it
if [[ $# -gt 0 ]]; then
  exec "$@"
fi

# Default: start gateway
exec openclaw gateway start
