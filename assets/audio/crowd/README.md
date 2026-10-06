# Crowd sounds

Original, generated, no third-party audio. Nothing here is sampled or downloaded.

| File | Length | What it is |
|---|---|---|
| `crowd_bed.wav` | 12 s, seamless loop | Distant murmur: low-passed noise with slow swells of ±3 dB. The loop end is crossfaded into its start, so it doesn't click. |
| `crowd_goal.wav` | 3.5 s | Rises over 0.4 s to a roar about 9 dB over the bed, then dies away. |
| `crowd_behind.wav` | 1.5 s | A short lift of about 4 dB. |
| `crowd_siren.wav` | 4 s | A roar with a two-tone siren (sines near 440 and 550 Hz). |

22050 Hz, mono, 16-bit. One gain is applied to all four so their levels stay in step; every peak is under −3 dBFS.

## How they are made

`tools/audio/build_crowd.py`, pure Python standard library (`wave`, `random`, `math`), seeded (2027), so the same command writes the same files:

```bash
python tools/audio/build_crowd.py
```

Change the shapes in that script and re-run it; don't edit the WAVs.
