# deltrivx/openclaw

Enhanced OpenClaw runtime image for Docker, based on `ghcr.io/openclaw/openclaw:latest`.

## What you get (batteries included)

- **Chromium** installed at `/usr/bin/chromium` (for real browser automation)
- **ffmpeg**
- **OCR/PDF**: tesseract (+ `chi_sim`), ocrmypdf, poppler-utils
- **Offline TTS**: `piper` + baked-in Chinese voice model `zh_CN-huayan-medium`
- **Python**: system `python3` stays in `/usr/bin/python3`, plus a venv at `/opt/venv` (preferred via `PATH`)
- **Skills default dir**: `/root/.agents/skills`
- **Gateway** default CMD runs in foreground for container compatibility

## Image

- `deltrivx/openclaw:latest`

## Notes

- Playwright should be configured to use the system Chromium via `executablePath: process.env.CHROME_PATH` (default `/usr/bin/chromium`).
- Piper wrapper:
  - `echo "你好" | piper-tts /tmp/out.wav`
