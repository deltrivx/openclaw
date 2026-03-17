#!/usr/bin/env python3
"""Minimal OpenAI-compatible /v1/audio/speech wrapper around Piper.

This is intentionally small and dependency-light.
- It is a best-effort helper for local TTS in the container.
- It is not required for OpenClaw core startup.
"""

from __future__ import annotations

import argparse
import os
import subprocess
from pathlib import Path

from fastapi import FastAPI, Response
from pydantic import BaseModel
import uvicorn


class SpeechReq(BaseModel):
    input: str
    voice: str | None = None
    response_format: str | None = "mp3"  # mp3|wav
    speed: float | None = 1.0


def run_piper(text: str, model_path: Path, out_path: Path):
    # Piper reads text from stdin
    cmd = ["piper", "--model", str(model_path), "--output_file", str(out_path)]
    subprocess.run(cmd, input=text.encode("utf-8"), check=True)


def wav_to_mp3(wav: Path, mp3: Path):
    cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(wav), str(mp3)]
    subprocess.run(cmd, check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=18793)
    ap.add_argument("--models-dir", default="/opt/piper/models")
    ap.add_argument("--voice", default="zh_CN-huayan-medium")
    args = ap.parse_args()

    models_dir = Path(args.models_dir)
    voice = args.voice

    app = FastAPI()

    @app.post("/v1/audio/speech")
    def speech(req: SpeechReq):
        v = req.voice or voice
        model = models_dir / f"{v}.onnx"
        if not model.exists():
            return Response(content=f"Model not found: {model}".encode(), status_code=404)

        tmp_wav = Path("/tmp/piper.wav")
        tmp_mp3 = Path("/tmp/piper.mp3")

        run_piper(req.input, model, tmp_wav)

        fmt = (req.response_format or "mp3").lower()
        if fmt == "wav":
            data = tmp_wav.read_bytes()
            return Response(content=data, media_type="audio/wav")

        wav_to_mp3(tmp_wav, tmp_mp3)
        data = tmp_mp3.read_bytes()
        return Response(content=data, media_type="audio/mpeg")

    uvicorn.run(app, host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    main()
