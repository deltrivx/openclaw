#!/usr/bin/env bash
set -euo pipefail

# OpenClaw container entrypoint
# Start tailscaled (required for `tailscale serve`) then start the gateway.

# Start tailscaled if present. Keep it in the background.
# IMPORTANT: disable proxy env for tailscaled.
# Some environments (e.g. Unraid with a LAN HTTP proxy) export HTTP(S)_PROXY/ALL_PROXY,
# which can break Tailscale controlplane connectivity and cause EOF / hostname-mismatch errors.
if command -v tailscaled >/dev/null 2>&1; then
  mkdir -p /var/run/tailscale || true
  echo "[entrypoint] starting tailscaled (proxy disabled)"

  # Use mounted state dir when available.
  # Unset proxy-related vars only for tailscaled so the rest of the container can still use proxies if needed.
  env -u HTTP_PROXY -u http_proxy \
      -u HTTPS_PROXY -u https_proxy \
      -u ALL_PROXY -u all_proxy \
      -u NO_PROXY -u no_proxy \
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
