import http from "node:http";
import { spawn } from "node:child_process";
import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";

const HOST = process.env.TTS_BIND ?? "127.0.0.1";
const PORT = Number(process.env.TTS_PORT ?? "18793");

const MODELS_DIR = process.env.PIPER_MODELS_DIR ?? "/opt/piper/models";
const DEFAULT_VOICE = process.env.PIPER_DEFAULT_VOICE ?? "zh_CN-huayan-medium";

const PIPER_BIN = process.env.PIPER_BIN ?? "/usr/local/bin/piper";
const PIPER_BIN_FALLBACK = process.env.PIPER_BIN_FALLBACK;
const FFMPEG_BIN = process.env.FFMPEG_BIN ?? "ffmpeg";

function sendJson(res, status, obj) {
  const body = Buffer.from(JSON.stringify(obj));
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "content-length": String(body.length),
  });
  res.end(body);
}

async function readJson(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const raw = Buffer.concat(chunks).toString("utf-8");
  if (!raw.trim()) return {};
  return JSON.parse(raw);
}

function run(cmd, args, { stdinText, env } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, { stdio: ["pipe", "pipe", "pipe"], env: env ?? process.env });
    let stderr = "";
    child.stderr.on("data", (d) => (stderr += d.toString("utf-8")));
    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) return resolve({ stderr });
      reject(new Error(`${cmd} exited with code ${code}: ${stderr}`));
    });
    // Avoid crashing on EPIPE when child exits early.
    child.stdin.on("error", () => {
      // ignore EPIPE
    });
    if (stdinText !== undefined) {
      try {
        child.stdin.write(stdinText);
      } catch {
        // ignore
      }
    }
    try {
      child.stdin.end();
    } catch {
      // ignore
    }
  });
}

async function fileSize(p) {
  try {
    const st = await fs.stat(p);
    return st.size;
  } catch {
    return 0;
  }
}

async function synthesize({ input, voice, response_format }) {
  const voiceName = (voice || DEFAULT_VOICE).trim();
  const fmt = (response_format || "mp3").trim();
  if (!input || typeof input !== "string") {
    throw new Error("Missing input");
  }
  if (fmt !== "mp3" && fmt !== "wav") {
    throw new Error(`Unsupported response_format: ${fmt}`);
  }

  const modelPath = path.join(MODELS_DIR, `${voiceName}.onnx`);
  const configPath = path.join(MODELS_DIR, `${voiceName}.onnx.json`);

  // create temp dir
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "openclaw-tts-"));
  const wavPath = path.join(dir, "out.wav");
  const mp3Path = path.join(dir, "out.mp3");

  // Piper reads text from stdin; write wav to file.
  // Some Piper bundles have different CLI behavior and/or ship extra shared libs alongside.
  const piperEnv = { ...process.env };
  // Prefer LD_LIBRARY_PATH so bundled .so next to the binary can be resolved.
  try {
    const binDir = path.dirname(PIPER_BIN);
    piperEnv.LD_LIBRARY_PATH = piperEnv.LD_LIBRARY_PATH
      ? `${binDir}:${piperEnv.LD_LIBRARY_PATH}`
      : binDir;
  } catch {
    // ignore
  }

  async function runPiper(bin, args) {
    return run(bin, args, { stdinText: input, env: piperEnv });
  }

  // Try with --config first, then without, then fallback binary if provided.
  const attempts = [];
  attempts.push([PIPER_BIN, ["--model", modelPath, "--config", configPath, "--output_file", wavPath]]);
  attempts.push([PIPER_BIN, ["--model", modelPath, "--output_file", wavPath]]);
  if (PIPER_BIN_FALLBACK) {
    attempts.push([PIPER_BIN_FALLBACK, ["--model", modelPath, "--config", configPath, "--output_file", wavPath]]);
    attempts.push([PIPER_BIN_FALLBACK, ["--model", modelPath, "--output_file", wavPath]]);
  }

  let lastErr;
  for (const [bin, args] of attempts) {
    try {
      await runPiper(bin, args);
      lastErr = null;
      break;
    } catch (e) {
      lastErr = e;
      console.error(`[tts] piper attempt failed: bin=${bin} args=${args.join(" ")} err=${String(e?.message || e)}`);
    }
  }
  if (lastErr) {
    throw lastErr;
  }

  const wavSize = await fileSize(wavPath);
  if (wavSize <= 44) {
    // 44 bytes is a WAV header size; treat as empty audio
    throw new Error(`Piper produced empty WAV (${wavSize} bytes)`);
  }

  if (fmt === "wav") {
    const buf = await fs.readFile(wavPath);
    return { contentType: "audio/wav", bytes: buf };
  }

  await run(FFMPEG_BIN, [
    "-y",
    "-hide_banner",
    "-loglevel",
    "error",
    "-i",
    wavPath,
    "-codec:a",
    "libmp3lame",
    "-q:a",
    "2",
    mp3Path,
  ]);
  const mp3Size = await fileSize(mp3Path);
  if (mp3Size <= 0) {
    throw new Error("ffmpeg produced empty mp3");
  }
  const buf = await fs.readFile(mp3Path);
  return { contentType: "audio/mpeg", bytes: buf };
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === "GET" && req.url === "/healthz") {
      res.writeHead(200, { "content-type": "text/plain" });
      res.end("ok");
      return;
    }

    if (req.method === "POST" && req.url === "/v1/audio/speech") {
      const body = await readJson(req);
      const { input, voice, response_format } = body;
      console.log(`[tts] request: voice=${voice || DEFAULT_VOICE} format=${response_format || "mp3"} chars=${typeof input === "string" ? input.length : 0}`);
      const out = await synthesize({ input, voice, response_format });
      console.log(`[tts] response: ${out.contentType} bytes=${out.bytes.length}`);
      res.writeHead(200, {
        "content-type": out.contentType,
        "content-length": String(out.bytes.length),
      });
      res.end(out.bytes);
      return;
    }

    sendJson(res, 404, { error: { message: "Not found" } });
  } catch (e) {
    sendJson(res, 500, { error: { message: String(e?.message || e) } });
  }
});

server.listen(PORT, HOST, () => {
  // eslint-disable-next-line no-console
  console.log(`[tts] listening on http://${HOST}:${PORT}`);
});
