#!/usr/bin/env bash
set -euo pipefail

# Ensure pipeline failures propagate (needed for tailscale serve diagnostics)
set -o pipefail

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

# Optional: start tailscaled so OpenClaw can use `tailscale serve`
# Use userspace networking to avoid requiring /dev/net/tun + NET_ADMIN in most setups.
if [ "${OPENCLAW_ENABLE_TAILSCALE:-}" = "1" ]; then
  mkdir -p /var/run/tailscale /var/lib/tailscale
  log "Starting tailscaled (userspace networking)"
  # Avoid proxy interference with Tailscale control-plane connections.
  TS_ENV=(env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u NO_PROXY)
  "${TS_ENV[@]}" tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state &
  TS_PID=$!

  # If an auth key is provided, bring the node up automatically.
  if [ -n "${TS_AUTHKEY:-}" ]; then
    log "Running tailscale up (authkey provided)"
    # best-effort: don't fail container boot if tailnet login fails
    "${TS_ENV[@]}" tailscale up --authkey="${TS_AUTHKEY}" --hostname="${TS_HOSTNAME:-openclaw}" --accept-dns=false || true

    # Wait briefly for Tailscale to reach Running
    for i in 1 2 3 4 5; do
      state="$("${TS_ENV[@]}" tailscale status --json 2>/dev/null | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{try{const j=JSON.parse(d);console.log(j.BackendState||"");}catch{console.log("");}})')" || true
      log "tailscale backend state: ${state:-<unknown>}"
      if [ "$state" = "Running" ]; then
        break
      fi
      sleep 1
    done

    log "tailscale ip: $("${TS_ENV[@]}" tailscale ip -4 2>/dev/null | tr '\n' ' ' || true)"

    # Try to enable tailscale serve for OpenClaw port (best-effort)
    set +e
    output="$("${TS_ENV[@]}" tailscale serve --bg --yes 18789 2>&1)"
    rc=$?
    set -e
    if [ $rc -eq 0 ]; then
      printf '%s\n' "$output" | sed 's/^/[tailscale serve] /'
      log "tailscale serve enabled for 18789"
    else
      printf '%s\n' "$output" | sed 's/^/[tailscale serve] /'
      log "tailscale serve failed (rc=$rc); dumping status"
      "${TS_ENV[@]}" tailscale status 2>&1 | sed 's/^/[tailscale status] /' || true
      "${TS_ENV[@]}" tailscale serve status 2>&1 | sed 's/^/[tailscale serve status] /' || true
    fi
  else
    log "TS_AUTHKEY not set; tailscaled running but not logged in"
  fi
else
  TS_PID=""
fi

# Start TTS server in background
node /app/tts-server.mjs &
TTS_PID=$!

# Start OpenClaw gateway (foreground)
# Keep args minimal; users can override CMD in docker run if needed.
node /app/openclaw.mjs gateway --allow-unconfigured

# If gateway exits, stop background services
kill "$TTS_PID" 2>/dev/null || true
if [ -n "${TS_PID:-}" ]; then
  kill "$TS_PID" 2>/dev/null || true
fi
