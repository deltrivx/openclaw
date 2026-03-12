# syntax=docker/dockerfile:1.7

# Multi-arch lightweight image with GitHub CLI (gh) preinstalled
# - Supports linux/amd64 and linux/arm64
# - Uses official release tarballs (version controllable via GH_VERSION)

ARG GH_VERSION=2.51.0
ARG TARGETOS
ARG TARGETARCH

FROM alpine:3.19 AS gh_fetch
ARG GH_VERSION
ARG TARGETOS
ARG TARGETARCH
RUN apk add --no-cache curl tar ca-certificates && update-ca-certificates
# Map Docker TARGETARCH to upstream archive suffix
# amd64 -> x86_64, arm64 -> arm64
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) GH_ARCH=x86_64 ;; \
      arm64) GH_ARCH=arm64 ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/gh.tgz \
      "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz"; \
    tar -C /tmp -xzf /tmp/gh.tgz; \
    mv "/tmp/gh_${GH_VERSION}_linux_${GH_ARCH}/bin/gh" /gh; \
    chmod +x /gh

FROM alpine:3.19
ARG GH_VERSION
LABEL org.opencontainers.image.title="Base with GitHub CLI" \
      org.opencontainers.image.description="Alpine base image with GitHub CLI (gh) preinstalled" \
      org.opencontainers.image.source="https://github.com/cli/cli" \
      org.opencontainers.image.version="${GH_VERSION}"

# Minimal runtime deps
RUN apk add --no-cache ca-certificates git openssh-client bash && update-ca-certificates

# Install gh
COPY --from=gh_fetch /gh /usr/local/bin/gh

# Verify install
RUN gh --version && git --version

# Optional: enable non-interactive auth via GH_TOKEN at runtime
# ENV GH_TOKEN=
# RUN [ -z "$GH_TOKEN" ] || printf "%s" "$GH_TOKEN" | gh auth login --with-token && gh auth setup-git

# Default working dir
WORKDIR /app

CMD ["bash"]
