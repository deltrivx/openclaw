#!/usr/bin/env bash
set -euo pipefail

# Install tailscale on Debian bookworm in a container-friendly way.
# Uses the official Tailscale apt repo + signed-by keyring.

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends ca-certificates curl gnupg

install -d -m 0755 /usr/share/keyrings

# Import signing key
curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.gpg \
  | gpg --dearmor -o /usr/share/keyrings/tailscale-archive-keyring.gpg
chmod 0644 /usr/share/keyrings/tailscale-archive-keyring.gpg

# Add apt repo
cat >/etc/apt/sources.list.d/tailscale.list <<'EOF'
deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian bookworm main
EOF

apt-get update
apt-get install -y --no-install-recommends tailscale

rm -rf /var/lib/apt/lists/*
