#!/usr/bin/env python3
"""Generate the original interface sounds in assets/audio/feel/ (game feel).

Footy-real, director 2026-10-11: a boot on leather for a main action, a stud
tapping concrete for a toggle, a siren blip at the end of a flow, and a short
sting (a thump and the crowd lifting) when a big moment lands.

Pure standard library (wave, random, math): no samples, no downloads, so the
provenance is ours. Seeded, so the same command writes the same files.

    python tools/audio/build_feel.py [out_dir]

Writes 22050 Hz mono 16-bit WAVs:
  kick_main.wav   ~0.16 s  a boot through the ball: a leather slap and a low thump
  kick_soft.wav   ~0.11 s  the same, lighter, for a secondary button
  stud_tick.wav   ~0.04 s  a stud tapping concrete, for a toggle or a tab
  siren_blip.wav  ~0.55 s  a short two-tone siren, the end of a flow
  sting.wav       ~1.3 s   a thump and a short crowd lift, a big moment landing
Peaks are set per file (see PEAKS_DB); none is over -3 dBFS.
"""
import math
import os
import random
import sys
import wave

RATE = 22050
SEED = 2031
PEAKS_DB = {
    "kick_main": -4.0,
    "kick_soft": -8.0,
    "stud_tick": -10.0,
    "siren_blip": -9.0,
    "sting": -4.0,
}


def db(x: float) -> float:
    return 10 ** (x / 20)


def lowpass(x, cutoff_hz, poles=1):
    a = 1 - math.exp(-2 * math.pi * cutoff_hz / RATE)
    out = list(x)
    for _ in range(poles):
        y = 0.0
        for i, v in enumerate(out):
            y += a * (v - y)
            out[i] = y
    return out


def highpass(x, cutoff_hz):
    lo = lowpass(x, cutoff_hz)
    return [a - b for a, b in zip(x, lo)]


def silence(secs):
    return [0.0] * int(secs * RATE)


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def normalise(x, peak_db):
    p = max(abs(v) for v in x) or 1.0
    g = db(peak_db) / p
    return [v * g for v in x]


def fade_tail(x, secs=0.006):
    n = min(len(x), int(secs * RATE))
    for i in range(n):
        x[len(x) - n + i] *= 1 - (i + 1) / n
    return x


def thump(secs, f0, f1, decay, amp=1.0):
    """A sine that drops in pitch as it dies: the body of a kicked ball."""
    out = []
    phase = 0.0
    n = int(secs * RATE)
    for i in range(n):
        t = i / RATE
        f = f1 + (f0 - f1) * math.exp(-t / (decay * 0.5))
        phase += 2 * math.pi * f / RATE
        env = math.exp(-t / decay) * min(1.0, t / 0.002)
        out.append(amp * env * math.sin(phase))
    return out


def slap(rng, secs, cutoff_lo, cutoff_hi, decay, amp=1.0):
    """Band-limited noise with a fast decay: leather, or a stud on concrete."""
    n = int(secs * RATE)
    noise = [rng.uniform(-1, 1) for _ in range(n)]
    band = lowpass(highpass(noise, cutoff_lo), cutoff_hi, poles=2)
    p = max(abs(v) for v in band) or 1.0
    return [amp * (v / p) * math.exp(-(i / RATE) / decay) for i, v in enumerate(band)]


def ping(secs, f, decay, amp=1.0):
    return [amp * math.exp(-(i / RATE) / decay) * math.sin(2 * math.pi * f * i / RATE)
            for i in range(int(secs * RATE))]


def kick(rng, secs, f0, f1, body_decay, slap_amp):
    body = thump(secs, f0, f1, body_decay)
    leather = slap(rng, 0.03, 700, 3800, 0.006, slap_amp)
    return fade_tail(mix(body, leather))


def siren(secs, tones=(440.0, 550.0)):
    """Two tones, a little buzz (odd harmonics) like a ground siren, soft edges."""
    n = int(secs * RATE)
    half = n // 2
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = tones[0] if i < half else tones[1]
        # a short glide between the tones so the change doesn't click
        if abs(i - half) < 200:
            k = (i - half + 200) / 400
            f = tones[0] + (tones[1] - tones[0]) * k
        phase += 2 * math.pi * f / RATE
        v = math.sin(phase) + 0.30 * math.sin(3 * phase) + 0.12 * math.sin(5 * phase)
        env = min(1.0, t / 0.03) * min(1.0, (secs - t) / 0.08)
        out.append(v * env)
    return out


def crowd_lift(rng, secs, rise, cutoff=900.0):
    n = int(secs * RATE)
    noise = lowpass([rng.uniform(-1, 1) for _ in range(n)], cutoff, poles=2)
    p = max(abs(v) for v in noise) or 1.0
    out = []
    for i, v in enumerate(noise):
        t = i / RATE
        env = min(1.0, t / rise) * math.exp(-max(0.0, t - rise) / (secs * 0.35))
        out.append(env * v / p)
    return fade_tail(out, 0.05)


def build(rng):
    s = {}
    s["kick_main"] = kick(rng, 0.16, 150.0, 58.0, 0.045, 0.55)
    s["kick_soft"] = kick(rng, 0.11, 190.0, 80.0, 0.030, 0.35)
    stud = mix(slap(rng, 0.04, 2500, 9000, 0.004, 1.0), ping(0.04, 3100.0, 0.006, 0.35))
    s["stud_tick"] = fade_tail(stud, 0.004)
    s["siren_blip"] = siren(0.55)
    hit = kick(rng, 0.25, 120.0, 45.0, 0.07, 0.6)
    lift = crowd_lift(rng, 1.3, 0.18)
    s["sting"] = mix(hit, [0.55 * v for v in lift])
    return {k: normalise(v, PEAKS_DB[k]) for k, v in s.items()}


def write(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            int(max(-1.0, min(1.0, v)) * 32767).to_bytes(2, "little", signed=True) for v in x))


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(__file__), "..", "..", "assets", "audio", "feel")
    os.makedirs(out_dir, exist_ok=True)
    rng = random.Random(SEED)
    for name, x in build(rng).items():
        path = os.path.join(out_dir, name + ".wav")
        write(path, x)
        peak = max(abs(v) for v in x)
        print("%-11s %.2f s  peak %.1f dBFS  %d bytes" % (
            name, len(x) / RATE, 20 * math.log10(peak), os.path.getsize(path)))


if __name__ == "__main__":
    main()
