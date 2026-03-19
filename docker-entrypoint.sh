#!/usr/bin/env bash
set -euo pipefail

# OpenClaw container entrypoint
# Start tailscaled (required for `tailscale serve`) then start the gateway.

# Start tailscaled if present. Keep it in the background.
if command -v tailscaled >/dev/null 2>&1; then
  mkdir -p /var/run/tailscale || true
  echo "[entrypoint] starting tailscaled"
  # Use mounted state dir when available.
  tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &
  # Give it a moment to create the socket.
  for i in $(seq 1 20); do
    [[ -S /var/run/tailscale/tailscaled.sock ]] && break
    sleep 0.2
  done
else
  echo "[entrypoint] tailscaled not found; tailscale serve will fail"
fi

exec node openclaw.mjs gateway --allow-unconfigured
