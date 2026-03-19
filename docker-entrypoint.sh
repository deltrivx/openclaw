#!/usr/bin/env bash
set -euo pipefail

# OpenClaw container entrypoint (official-like behavior)
# - Do NOT auto-run `openclaw doctor --fix`
# - Do NOT disable/rename built-in extensions
# - Do NOT override plugin discovery roots

exec node openclaw.mjs gateway --allow-unconfigured
