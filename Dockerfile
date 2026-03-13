# 修复点：你日志里的 RUN 语句少了很多 “|| true”，且把 ( … ) 写成了函数调用样式，导致语法错误。
# 下面这段是可直接替换的 apt 安装层（仅缓存 /var/cache/apt，带锁清理 + 重试，语法严格）。

RUN --mount=type=cache,target=/var/cache/apt \
    set -eux; \
    # 清理潜在 apt/dpkg 锁
    rm -f /var/lib/apt/lists/lock || true; \
    rm -f /var/cache/apt/archives/lock || true; \
    rm -f /var/lib/dpkg/lock-frontend || true; \
    dpkg --configure -a || true; \
    # apt-get update（带重试）
    for i in 1 2 3; do \
      if apt-get update; then \
        break; \
      else \
        echo "[warn] apt-get update failed, retry #$i" >&2; \
        sleep 2; \
        rm -f /var/lib/apt/lists/lock || true; \
        rm -f /var/cache/apt/archives/lock || true; \
        rm -f /var/lib/dpkg/lock-frontend || true; \
        dpkg --configure -a || true; \
      fi; \
    done; \
    # 安装系统依赖
    apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg git openssh-client bash \
      chromium chromium-common chromium-driver ffmpeg \
      tesseract-ocr tesseract-ocr-chi-sim \
      ocrmypdf poppler-utils qpdf ghostscript pngquant \
      nodejs npm; \
    # gh 官方仓库 keyring
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null; \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list; \
    # 再次 update（带重试）
    for i in 1 2 3; do \
      if apt-get update; then \
        break; \
      else \
        echo "[warn] apt-get update (gh repo) failed, retry #$i" >&2; \
        sleep 2; \
        rm -f /var/lib/apt/lists/lock || true; \
        rm -f /var/cache/apt/archives/lock || true; \
        rm -f /var/lib/dpkg/lock-frontend || true; \
        dpkg --configure -a || true; \
      fi; \
    done; \
    apt-get install -y --no-install-recommends gh; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*
