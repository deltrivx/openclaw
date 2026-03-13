#!/usr/bin/env bash
set -euo pipefail

echo "== Versions =="
node -v
chromium --version || true
ffmpeg -version | head -n 2
python3 -c "import faster_whisper, ctranslate2; print('faster-whisper OK', faster_whisper.__version__)"
/opt/piper/piper --help >/dev/null && echo "piper OK"
tesseract --version | head -n 2
ocrmypdf --version
pdftotext -v 2>&1 | head -n 1
openclaw --help | head -n 5

echo "== Done =="
