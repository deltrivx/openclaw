#!/usr/bin/env python3
"""Patch user-visible onboard CLI strings in the *built* OpenClaw JS output.

Why:
- We cannot run local builds per repo rules.
- Base image already ships compiled dist.
- To make onboard Chinese immediately, we patch strings in-place during Docker build.

Safety:
- Only performs exact string replacements.
- Limits to text-like files under common app roots.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOTS = [
    Path("/app"),
    Path("/usr/local"),
    Path("/usr/lib"),
]

# Exact replacements (keep them conservative)
REPLACEMENTS: list[tuple[str, str]] = [
    # Auth choice deprecation (template pieces)
    ('Auth choice "', '认证方式 "'),
    ('" is deprecated.', '" 已弃用。'),
    ('Use "--auth-choice token" (Anthropic setup-token) or "--auth-choice openai-codex".',
     '请使用 "--auth-choice token"（Anthropic setup-token）或 "--auth-choice openai-codex"。'),

    # Invalid flags
    ('Invalid --secret-input-mode. Use "plaintext" or "ref".',
     '无效的 --secret-input-mode。请使用 "plaintext" 或 "ref"。'),
    ('Invalid --reset-scope. Use "config", "config+creds+sessions", or "full".',
     '无效的 --reset-scope。请使用 "config"、"config+creds+sessions" 或 "full"。'),

    # Non-interactive risk acknowledgement
    ('Non-interactive setup requires explicit risk acknowledgement.',
     '非交互式安装需要显式确认风险。'),
    ('Read: https://docs.openclaw.ai/security',
     '请阅读：https://docs.openclaw.ai/security'),
    ('Re-run with: ',
     '请使用以下命令重新运行：'),

    # Windows hint
    ('Windows detected - OpenClaw runs great on WSL2!',
     '检测到 Windows —— OpenClaw 在 WSL2 上运行体验更好！'),
    ('Native Windows might be trickier.',
     '原生 Windows 环境可能更棘手。'),
    ('Quick setup: wsl --install (one command, one reboot)',
     '快速安装：wsl --install（1 条命令 + 1 次重启）'),
    ('Guide: https://docs.openclaw.ai/windows',
     '指南：https://docs.openclaw.ai/windows'),
]

TEXT_EXTS = {".js", ".mjs", ".cjs", ".ts", ".tsx", ".json", ".map", ".md", ".txt"}


def iter_files(root: Path):
    if not root.exists():
        return
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        if p.suffix in TEXT_EXTS or p.name in {"openclaw.mjs"}:
            yield p


def patch_file(p: Path) -> int:
    try:
        data = p.read_bytes()
    except Exception:
        return 0

    # Skip very large binaries
    if len(data) > 5_000_000:
        return 0

    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return 0

    original = text
    for old, new in REPLACEMENTS:
        if old in text:
            text = text.replace(old, new)

    if text == original:
        return 0

    p.write_text(text, encoding="utf-8")
    return 1


def main() -> int:
    changed_files = 0
    scanned = 0
    for root in ROOTS:
        for p in iter_files(root):
            scanned += 1
            changed_files += patch_file(p)

    print(f"[patch_onboard_dist] scanned={scanned} changed={changed_files}")
    # Non-fatal if nothing matched (upstream may have moved strings)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
