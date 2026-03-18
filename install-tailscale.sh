#!/usr/bin/env bash
set -euo pipefail

# Install tailscale on Debian/Ubuntu in a container-friendly way.
# Uses the official Tailscale apt repo.

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends ca-certificates curl gnupg

install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg \
  | tee /etc/apt/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list \
  | tee /etc/apt/sources.list.d/tailscale.list >/dev/null

apt-get update
apt-get install -y --no-install-recommends tailscale

rm -rf /var/lib/apt/lists/*
