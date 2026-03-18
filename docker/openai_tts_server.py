from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

app = FastAPI(title="OpenAI-compatible Piper TTS")

PIPER_MODELS_DIR = Path(os.environ.get("PIPER_MODELS_DIR", "/opt/piper/models"))
DEFAULT_VOICE = os.environ.get("PIPER_VOICE", "zh_CN-huayan-medium")
FFMPEG_BIN = shutil.which("ffmpeg") or "/usr/bin/ffmpeg"
PIPER_BIN = shutil.which("piper") or "/opt/venv/bin/piper"


class SpeechRequest(BaseModel):
    model: str | None = "tts-1"
    input: str
    voice: str | None = None
    response_format: str | None = "mp3"
    speed: float | None = 1.0


def resolve_voice(voice: str | None) -> tuple[Path, Path]:
    name = (voice or DEFAULT_VOICE).strip()
    onnx = PIPER_MODELS_DIR / f"{name}.onnx"
    config = PIPER_MODELS_DIR / f"{name}.onnx.json"
    if not onnx.exists() or not config.exists():
        raise HTTPException(status_code=400, detail=f"voice not found: {name}")
    return onnx, config


@app.get("/health")
def health():
    return {
        "ok": True,
        "piper": PIPER_BIN,
        "ffmpeg": FFMPEG_BIN,
        "modelsDir": str(PIPER_MODELS_DIR),
        "defaultVoice": DEFAULT_VOICE,
    }


@app.post("/v1/audio/speech")
def speech(req: SpeechRequest):
    text = (req.input or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="input is required")

    fmt = (req.response_format or "mp3").lower()
    if fmt not in {"mp3", "wav"}:
        raise HTTPException(status_code=400, detail="response_format must be mp3 or wav")

    voice_onnx, voice_json = resolve_voice(req.voice)

    with tempfile.TemporaryDirectory(prefix="piper-tts-") as td:
        td_path = Path(td)
        wav_path = td_path / "speech.wav"
        out_path = td_path / ("speech.mp3" if fmt == "mp3" else "speech.wav")

        cmd = [
            PIPER_BIN,
            "--model", str(voice_onnx),
            "--config", str(voice_json),
            "--output_file", str(wav_path),
        ]
        proc = subprocess.run(
            cmd,
            input=text.encode("utf-8"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if proc.returncode != 0:
            raise HTTPException(status_code=500, detail=f"piper failed: {proc.stderr.decode('utf-8', 'ignore')[:500]}")
        if not wav_path.exists() or wav_path.stat().st_size == 0:
            raise HTTPException(status_code=500, detail="piper produced empty wav (0KB)")

        if fmt == "wav":
            media_type = "audio/wav"
            return FileResponse(path=wav_path, media_type=media_type, filename="speech.wav")

        ff = subprocess.run(
            [FFMPEG_BIN, "-y", "-i", str(wav_path), "-codec:a", "libmp3lame", "-q:a", "2", str(out_path)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if ff.returncode != 0:
            raise HTTPException(status_code=500, detail=f"ffmpeg failed: {ff.stderr.decode('utf-8', 'ignore')[:500]}")
        if not out_path.exists() or out_path.stat().st_size == 0:
            raise HTTPException(status_code=500, detail="ffmpeg produced empty mp3 (0KB)")

        return FileResponse(path=out_path, media_type="audio/mpeg", filename="speech.mp3")
