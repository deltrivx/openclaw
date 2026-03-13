# syntax=docker/dockerfile:1.7

FROM ghcr.io/openclaw/openclaw:latest

USER root
ARG DEBIAN_FRONTEND=noninteractive

# Make apt usable in upstream images that may run non-root or have missing partial dirs.
RUN mkdir -p /var/lib/apt/lists/partial /var/cache/apt/archives/partial \
 && chmod -R 755 /var/lib/apt/lists /var/cache/apt

# ---- Base OS tools + runtime deps ----
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git unzip xz-utils bash tini \
    ffmpeg \
    tesseract-ocr tesseract-ocr-chi-sim \
    ocrmypdf \
    poppler-utils \
    fonts-noto-cjk fonts-noto-color-emoji \
    python3 python3-pip \
 && rm -rf /var/lib/apt/lists/*

# ---- Node 20+ (ensure) ----
RUN if ! node -v 2>/dev/null | grep -q '^v20\.'; then \
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
      && apt-get update \
      && apt-get install -y --no-install-recommends nodejs \
      && rm -rf /var/lib/apt/lists/*; \
    fi

# ---- GitHub CLI (gh) ----
RUN type -p gh >/dev/null 2>&1 || ( \
      mkdir -p /etc/apt/keyrings \
      && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
      && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
      && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
      && apt-get update \
      && apt-get install -y --no-install-recommends gh \
      && rm -rf /var/lib/apt/lists/* \
    )

# ---- ClawHub CLI ----
RUN npm i -g clawhub@latest

# ---- Browser automation (Playwright + bundled Chromium) ----
# 1) Global Playwright (Node)
# 2) Bundle Playwright Chromium into /ms-playwright
# 3) Expose stable /usr/bin/chromium + /usr/bin/google-chrome symlinks
# 4) Set Chinese locale-related defaults
ENV LANG=zh_CN.UTF-8
ENV LC_ALL=zh_CN.UTF-8
ENV NODE_PATH=/usr/local/lib/node_modules
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN npm i -g playwright@1.58.2 \
 && npx playwright install chromium \
 && node -p "require('playwright/package.json').version" \
 && CHROME_BIN="$(find /ms-playwright -type f \( -path '*/chrome-linux*/chrome' -o -path '*/chrome-linux*/chrome-wrapper' -o -path '*/chrome-linux64/chrome' \) 2>/dev/null | head -n 1)" \
 && test -n "$CHROME_BIN" \
 && ln -sf "$CHROME_BIN" /usr/bin/chromium

# ---- Python packages ----
# Install into system python3 (user confirmed using --break-system-packages).
# - faster-whisper + ctranslate2 (prefer wheels)
# - playwright (python)
# - edge-tts
# - pyyaml
RUN python3 -m pip install --no-cache-dir --break-system-packages --upgrade pip \
 && python3 -m pip install --no-cache-dir --break-system-packages --only-binary=:all: faster-whisper ctranslate2 \
 && python3 -m pip install --no-cache-dir --break-system-packages "playwright>=1.50,<2" edge-tts pyyaml \
 && python3 -c "import yaml; print('pyyaml ok')" \
 && python3 -c "import edge_tts; print('edge-tts ok')" \
 && python3 -c "import playwright; print('python-playwright ok')"

# ---- Skills directory convention ----
# You requested skills default to /root/.agents/skills.
# We create it and symlink the workspace skills dir to it for compatibility.
RUN mkdir -p /root/.agents/skills \
 && mkdir -p /root/.openclaw/workspace \
 && ln -sfn /root/.agents/skills /root/.openclaw/workspace/skills

ENV TERM=xterm-256color
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["openclaw","gateway","start"]
