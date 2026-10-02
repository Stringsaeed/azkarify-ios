"""Builds the app preview soundtrack from cues.json: synthesized whooshes/ticks plus the
project's own reward sounds (docs/design/sounds). No music, by design.
Usage: python audio.py <cues.json> <out.wav>"""
import json, sys, wave
from pathlib import Path
import numpy as np

SR = 48000
ASSETS = Path(__file__).parent / "assets"
rng = np.random.default_rng(7)


def load(name):
    with wave.open(str(ASSETS / f"{name}.wav")) as w:
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768
        if w.getnchannels() == 2:
            data = data.reshape(-1, 2).mean(axis=1)
        if w.getframerate() != SR:
            x = np.arange(0, len(data), w.getframerate() / SR)
            data = np.interp(x, np.arange(len(data)), data)
    return data / (np.abs(data).max() + 1e-9) * 0.6


def whoosh(d=0.32):
    n = int(SR * d)
    noise = rng.standard_normal(n)
    # Sweep a one-pole low-pass upward then down for an airy pass-by.
    t = np.linspace(0, 1, n)
    cutoff = 300 + 5200 * np.sin(np.pi * t) ** 2
    out = np.zeros(n)
    y = 0.0
    for i in range(n):
        a = 1 - np.exp(-2 * np.pi * cutoff[i] / SR)
        y += a * (noise[i] - y)
        out[i] = y
    env = np.sin(np.pi * t) ** 1.6
    return out * env * 0.55


def tick():
    n = int(SR * 0.09)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * 1450 * t) * np.exp(-t * 70) + 0.5 * np.sin(2 * np.pi * 880 * t) * np.exp(-t * 45)
    click = rng.standard_normal(n) * np.exp(-t * 900) * 0.4
    return (body + click) * 0.35


def boom():
    n = int(SR * 0.9)
    t = np.arange(n) / SR
    f = 95 * np.exp(-t * 3) + 45
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) * np.exp(-t * 4.5) * 0.7


SYNTH = {"whoosh": whoosh, "tick": tick, "boom": boom}


def main(cues_path, out_path):
    cues = json.loads(Path(cues_path).read_text())
    total = int(SR * (cues["total"] + 0.2))
    left = np.zeros(total)
    right = np.zeros(total)
    cache = {}
    for i, c in enumerate(cues["sfx"]):
        name = c["name"]
        if name not in cache or name == "whoosh":
            cache[name] = SYNTH[name]() if name in SYNTH else load(name)
        clip = cache[name] * c.get("gain", 1)
        start = max(0, int(SR * c["t"]))
        end = min(total, start + len(clip))
        # Light stereo movement on whooshes; everything else centered.
        pan = 0.35 * (1 if i % 2 else -1) if name == "whoosh" else 0
        left[start:end] += clip[: end - start] * (1 - pan)
        right[start:end] += clip[: end - start] * (1 + pan)
    stereo = np.stack([left, right], axis=1)
    peak = np.abs(stereo).max()
    stereo = stereo / peak * 0.89  # about -1 dBFS
    fade = int(SR * 0.15)
    stereo[-fade:] *= np.linspace(1, 0, fade)[:, None]
    pcm = (stereo * 32767).astype(np.int16)
    with wave.open(out_path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
