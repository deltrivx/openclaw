# syntax=docker/dockerfile:1

# Stable, multi-arch friendly base with GitHub CLI preinstalled via Alpine packages
# Works on linux/amd64 and linux/arm64 without extra ARGs

FROM alpine:3.19

# Base tools + gh
RUN apk add --no-cache \
      ca-certificates \
      git \
      openssh-client \
      bash \
      gh \
  && update-ca-certificates

# Verify
RUN gh --version && git --version

# Optional: enable non-interactive auth at runtime with GH_TOKEN
# ENV GH_TOKEN=
# RUN [ -z "$GH_TOKEN" ] || printf "%s" "$GH_TOKEN" | gh auth login --with-token && gh auth setup-git

WORKDIR /app
CMD ["bash"]
