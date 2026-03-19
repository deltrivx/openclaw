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

disable_problem_plugins() {
  # Remove incompatible plugins that can crash during load.
  # This is a stability measure; we can re-enable after updating extensions.
  python3 - "$CONFIG_FILE" <<'PY'
import json, sys
p=sys.argv[1]
try:
  with open(p,'r',encoding='utf-8') as f:
    cfg=json.load(f)
except Exception:
  sys.exit(0)
plugins = cfg.get('plugins')
if not isinstance(plugins, dict):
  sys.exit(0)
entries = plugins.get('entries')
if isinstance(entries, dict):
  changed=False
  for k in ['copilot-proxy','qwen-portal-auth']:
    if k in entries:
      entries.pop(k, None)
      changed=True
  if changed:
    plugins['entries']=entries
    cfg['plugins']=plugins
    with open(p,'w',encoding='utf-8') as f:
      json.dump(cfg,f,ensure_ascii=False,indent=2)
PY
}

# Run at most once per container boot.
if [[ -f "$CONFIG_FILE" ]] && [[ ! -f "$STAMP_FILE" ]]; then
  touch "$STAMP_FILE" || true
  run_fix
  disable_problem_plugins || true
fi

# Start gateway (preserve upstream behavior)
exec node openclaw.mjs gateway --allow-unconfigured
