# Button and moment sounds (game feel)

Original, generated, no third-party audio. Nothing here is sampled or downloaded.
Footy-real (director, 2026-10-11).

| File | Length | Plays when |
|---|---|---|
| `kick_main.wav` | 0.16 s | The primary action is pressed: a boot through the ball (a leather slap over a low thump that drops in pitch). |
| `kick_soft.wav` | 0.11 s | Any other button: the same, lighter. |
| `stud_tick.wav` | 0.04 s | A choice or a tab: a stud tapping concrete. |
| `siren_blip.wav` | 0.55 s | The end of a flow (full time's Continue, the end of the draft): a short two-tone siren. |
| `sting.wav` | 1.3 s | A big moment lands (the result, your draft pick, your ladder spot moving): a thump and a short crowd lift. |

22050 Hz, mono, 16-bit, each under 60 KB. Played on the `Interface` bus under Master (`scripts/ui/Feel.gd`),
so Settings > Button sounds sets them and Mute sounds silences them with everything else.

## How they are made

`tools/audio/build_feel.py`, pure Python standard library, seeded (2031), so the same command writes the same files:

```bash
python tools/audio/build_feel.py
```

Change the shapes in that script and re-run it; don't edit the WAVs.
