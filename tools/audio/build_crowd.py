#!/usr/bin/env python3
"""Generate the original crowd sounds in assets/audio/crowd/ (FL-004).

Pure standard library (wave, random, math): no samples, no downloads, so the
provenance is ours. Seeded, so the same command writes the same files.

    python tools/audio/build_crowd.py [out_dir]

Writes 22050 Hz mono 16-bit WAVs:
  crowd_bed.wav     12 s seamless loop of distant murmur (slow swells of +-3 dB)
  crowd_goal.wav    ~3.5 s, rises over 0.4 s to a roar ~9 dB over the bed, then decays
  crowd_behind.wav  ~1.5 s, a short lift of ~4 dB
  crowd_siren.wav   ~4 s, a roar plus a two-tone siren (sines near 440 and 550 Hz)
All peaks stay under -3 dBFS.
"""
import math
import os
import random
import sys
import wave

RATE = 22050
BED_SECS = 12.0
BED_RMS = 0.05            # the bed's loudness (about -26 dBFS) before the roars ride on it
PEAK_CEIL = 10 ** (-3 / 20)   # -3 dBFS
SEED = 2027


def db(x: float) -> float:
    return 10 ** (x / 20)


def lowpass(noise, cutoff_hz, poles=2):
    """One-pole low-pass, applied `poles` times."""
    a = 1 - math.exp(-2 * math.pi * cutoff_hz / RATE)
    out = list(noise)
    for _ in range(poles):
        y = 0.0
        for i, x in enumerate(out):
            y += a * (x - y)
            out[i] = y
    return out


def rms(x):
    return math.sqrt(sum(v * v for v in x) / len(x))


def scaled_to_rms(x, target):
    g = target / rms(x)
    return [v * g for v in x]


def murmur(rng, n, cutoff):
    """Low-passed noise, normalised to unit RMS (a crowd: a lot of low, a little air)."""
    body = lowpass([rng.uniform(-1, 1) for _ in range(n)], cutoff)
    air = lowpass([rng.uniform(-1, 1) for _ in range(n)], cutoff * 3, poles=1)
    mix = [b + 0.15 * a for b, a in zip(body, air)]
    return scaled_to_rms(mix, 1.0)


def swell(i, n):
    """Slow swells of +-3 dB. Whole cycles per loop (so the swell wraps cleanly)."""
    s = sum(math.sin(2 * math.pi * c * i / n + p) for c, p in zip(SWELL_CYCLES, SWELL_PHASE)) / 3
    return db(3 * s)


def make_bed(rng):
    n = int(RATE * BED_SECS)
    fade = int(RATE * 1.0)
    raw = murmur(rng, n + fade, 700)
    sw = [raw[i] * swell(i, n) for i in range(n + fade)]
    # Crossfade the extra tail into the head (equal power): the loop point has no click.
    out = sw[:n]
    for i in range(fade):
        w = i / fade
        out[i] = sw[i] * math.sin(w * math.pi / 2) + sw[n + i] * math.cos(w * math.pi / 2)
    return scaled_to_rms(out, BED_RMS)


def roar(rng, secs, rise, peak_db, decay_s):
    """A roar that rises over `rise` seconds to `peak_db` over the bed, then decays."""
    n = int(RATE * secs)
    raw = murmur(rng, n, 1100)
    out = []
    for i in range(n):
        t = i / RATE
        if t < rise:
            e = math.sin(t / rise * math.pi / 2) ** 2
        else:
            e = math.exp(-(t - rise) / decay_s)
        out.append(raw[i] * BED_RMS * db(peak_db) * e)
    return out


def fade_out(x, secs):
    k = int(RATE * secs)
    for i in range(k):
        x[len(x) - 1 - i] *= i / k
    return x


def mix(*layers):
    n = max(len(x) for x in layers)
    return [sum(x[i] for x in layers if i < len(x)) for i in range(n)]


def make_siren(rng):
    n = int(RATE * 4.0)
    tone = []
    for i in range(n):
        t = i / RATE
        e = min(1.0, t / 0.05) * min(1.0, (4.0 - t) / 0.6)
        tone.append(0.5 * BED_RMS * db(9) * e * (math.sin(2 * math.pi * 440 * t) + 0.8 * math.sin(2 * math.pi * 550 * t)))
    return mix(roar(rng, 4.0, 0.6, 6, 1.6), tone)


def write(path, samples, gain):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(int(max(-1, min(1, v * gain)) * 32767).to_bytes(2, "little", signed=True)
                               for v in samples))


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join("assets", "audio", "crowd")
    os.makedirs(out_dir, exist_ok=True)
    rng = random.Random(SEED)
    files = {
        "crowd_bed.wav": make_bed(rng),
        "crowd_goal.wav": fade_out(mix(roar(rng, 3.5, 0.4, 9, 0.9), make_bed(rng)[:int(RATE * 3.5)]), 0.3),
        "crowd_behind.wav": fade_out(roar(rng, 1.5, 0.25, 4, 0.5), 0.2),
        "crowd_siren.wav": make_siren(rng),
    }
    # One gain for all four keeps their levels in step; it only comes down to hold the ceiling.
    peak = max(max(abs(v) for v in x) for x in files.values())
    gain = min(1.0, PEAK_CEIL / peak)
    for name, x in files.items():
        write(os.path.join(out_dir, name), x, gain)
        print("%-18s %5.2f s  peak %6.1f dBFS" % (name, len(x) / RATE, 20 * math.log10(max(abs(v) for v in x) * gain)))


SWELL_CYCLES = [3, 5, 8]      # 4 s, 2.4 s and 1.5 s swells over the 12 s loop
SWELL_PHASE = [0.4, 2.1, 4.0]

if __name__ == "__main__":
    main()
