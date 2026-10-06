# Scene baselines, 2026-10-06 ("before" for the animation and camera prototypes)

The four existing capture tools, run unchanged on main at `db7d76a`, on a real renderer (OpenGL compatibility, a Windows desktop with an RTX 4070), at phone size. These are the "before" images for the director's animation and camera research. Nothing here is a design; they are what the game draws today.

| File | Tool | What it shows |
|---|---|---|
| `vignette_sheet.png` | `tools/visual/capture_vignette.gd` | The centre-bounce scene (`StoppageVignette`) at six beats on a 390 x 844 phone, then the coach's call. Six panels in two rows: the empty ground, the walk in, the settle, the bounce, the call arriving, the call card. |
| `broadcast_360.png` | `capture_broadcast.gd --width 360 --scale 0.5` | Every broadcast close-up kind (speccy front, side, defensive, after the siren, goal-line crumb, boundary snap), one row per kind and one column per beat. |
| `press_360.png` | `capture_press.gd --width 360` | The post-match press conference scene at its beats: walking in, sitting down, settled, answering. |
| `awards_360.png` | `capture_awards.gd --width 360` | The award winner's walk-on in the ceremony at its beats: walking on, turned to us, medal on, arms up. |

## How they were run

```
godot --path . --rendering-method gl_compatibility --script tools/visual/capture_vignette.gd -- --out <dir>/vignette
godot --path . --rendering-method gl_compatibility --script tools/visual/capture_broadcast.gd -- --out <dir>/broadcast --width 360 --scale 0.5
godot --path . --rendering-method gl_compatibility --script tools/visual/capture_press.gd -- --out <dir>/press --width 360
godot --path . --rendering-method gl_compatibility --script tools/visual/capture_awards.gd -- --out <dir>/awards --width 360
```

Godot 4.7.2, one run each, default seeds (the tools stage their own fixtures and never touch a save).

## Read these as they are

- In `vignette_sheet.png` the first beat is the bare ground before the figures walk in, and the buttons on the coach's call card draw as empty coloured bars in this capture; the card text above them draws. The card is a UI overlay on the 3D view, and how it draws under the capture tool differs from how it draws in the game. Do not take the bars as a game defect without checking in the running game.
- The tools lay their panels out at a fixed phone size and clip what runs past it (the right-hand panels in the vignette sheet). That is the tool's layout, not the scene's.
- `broadcast_360.png` is large (about 2.5 MB) because it is every close-up at every beat.
- These are single captures on one machine. If a prototype is compared against them, re-run the same tool with the same arguments on the same machine for the "after".
