# Performance baseline (2026-10-06)

Measured on the director's PC, not on a phone. **No Android device was measured.** Every number here is a PC number from the Mobile renderer, so treat it as a yardstick for comparing changes, not as how the game runs on a phone. The device gate is the director's: "PC now, phone later". We baseline and compare on this PC; he runs an Android build on his phone before anything merges and reports back.

## Method

- Machine: Windows 11, NVIDIA GeForce RTX 4070 SUPER, Godot 4.7.2, `--rendering-method mobile` (the project's Mobile renderer).
- The window is kept off screen and unfocused (an untracked `override.cfg`), 540 by 960 before content scaling; frames are real rendered frames, not headless.
- One Godot process at a time, with the save folder pointed at a scratch directory, so nothing touches a real save.
- Rerun with `tools/perf/run_baseline.sh [out-file]` (set `GODOT` to the executable). It runs `tools/perf/baseline.gd` twice and prints the `PERF` lines; run `godot --headless --import` first on a fresh checkout so the script classes resolve.
- One run is quoted below. Launch times are one sample, so expect a spread of 10 to 20 percent between runs; the file cache was not flushed, so "cold" here means the first load in a process, not a cold disk.
- The scenes were loaded with a started career (Geelong, 2027 pre-season) and added to the root; "first draw" is the time to the second rendered frame.

## Results

| What | Time |
|---|---|
| Engine start to the first script frame (includes the GameDB and the other autoloads) | 2.1 s |
| GameDB reload | 0.14 s (20 clubs) |
| Hub, first load (load, instance, first draw) | 730 ms, 32 ms, 99 ms |
| Hub, second load (resources cached) | 0 ms, 27 ms, 7 ms |
| Launch to a drawn Hub, adding the above | about 3.0 s first, the cached Hub adds about 35 ms |

Main scenes, first load in the process:

| Scene | Load | Instance and ready | First draw |
|---|---|---|---|
| List | 216 ms | 17 ms | 7 ms |
| Selection | 241 ms | 42 ms | 14 ms |
| Ladder | 102 ms | 7 ms | 3 ms |
| Training | 237 ms | 18 ms | 13 ms |
| Staff | 151 ms | 3 ms | 2 ms |
| Coaching | 149 ms | 29 ms | 5 ms |
| Offseason | 290 ms | **1692 ms** | 8 ms |
| Season review | 315 ms | 9 ms | 12 ms |

The Offseason scene's 1.7 s to get ready is the one outlier; everything else is under a quarter of a second.

| What | Result |
|---|---|
| Autosave (7 saves, a started career) | median 87 ms, slowest 91 ms, file 1.7 MB |
| First broadcast vignette (goal line) | setup 3 ms; first frame 84 ms, then median 16.7 ms, slowest 18.3 ms |
| `MatchSim.run` for one match | 191 ms (1443 events) |
| Live match view, 600 frames | median 16.6 ms, 95th percentile 17.8 ms, slowest 75.1 ms, one frame over 33 ms |
| Draw calls in the match view | median 196, most 206 |

Reading it: the match view holds 60 frames a second on this PC with one slow frame in 600 (75 ms, once). The first vignette costs one 84 ms frame the first time it draws. Draw calls sit near 200. Whether a mid-range phone holds that is not known.

## Idle and redraw audit (medium, item 23)

`tools/visual/measure_idle.gd` on branch `claude/idle-audit`: a live match screen (Collingwood career, MatchScene) at phone portrait 412 by 915, the project's renderer, low-processor mode on, 60 fps cap. Three-second windows count frames drawn, main-loop ticks, redraws per node and nodes with processing on; the per-tick cost of each processing node comes from timing its `_process` 2000 times.

| State | Frames drawn a second | Redraws a second | Processing |
|---|---|---|---|
| Playing | 60 | the pitch 60, a caption label about 12, the clock and feed under 1 | the pitch |
| Paused, once it settles | 0 | none | the pitch (3.4 µs a tick) |
| Paused, first 6 s | 13, 3, 1, 0, 0, 0 | the camera's ease-out, then it stops | |
| Player sheet over a paused match | 0 | none | the pitch |
| Player sheet over a playing match | 60 | the pitch 60 (still visible behind the sheet) | the pitch |
| Stoppage call, frozen scene | 0 | none | the pitch, the stoppage vignette (0.1 µs a tick) |
| Backgrounded (focus out and paused sent) | 0 | none | as before |

Nothing redraws when nothing changes. The main loop still ticks 60 times a second in every state, even with nothing processing (Godot's own low-processor loop); only rendering stops. Nothing measured needs a fix, so no code changed. Not measured: a real phone, and Android's own pause, where the OS stops the loop.

## Anti-aliasing cost (medium, #472 and #478)

GPU time for a frame of the pitch and of the stoppage vignette, on this PC's Mobile renderer, measured with the method in #472 (line anti-aliasing, step 1) and #478 (whole-game anti-aliasing).

| Case | GPU time |
|---|---|
| Pitch, no anti-aliasing | 0.087 ms |
| Pitch, line anti-aliasing | 0.117 ms |
| Pitch, 2x MSAA | 0.157 ms |
| Stoppage vignette, before | 0.097 ms |
| Stoppage vignette, 2x MSAA | 0.170 ms |

These are PC numbers. A phone's GPU will cost more per frame, so the phone check before merge is the real test.

## Texture import inventory (for the art agent)

Every texture under `assets/vignette` and `assets/ui`, from the committed `.import` files (`python3 tools/perf/texture_inventory.py`). Filtering is not an import setting in Godot 4; it comes from the project default unless a node or shader overrides it. The figure shader sets `filter_linear` on the mask, design and digits samplers.

| texture | size | compress mode | mipmaps | filter |
|---|---|---|---|---|
| `assets/vignette/figures_design.png` | 1024x1334 | lossless | false | project default |
| `assets/vignette/figures_digits.png` | 640x96 | lossless | false | project default |
| `assets/vignette/figures_mask.png` | 2048x2668 | VRAM compressed | false | project default |
| `assets/vignette/figures_shade.png` | 2048x2668 | VRAM compressed | false | project default |
| `assets/vignette/hair_bald.png` | 1024x276 | VRAM compressed | false | project default |
| `assets/vignette/hair_dreadlocks.png` | 1024x480 | VRAM compressed | false | project default |
| `assets/vignette/hair_short_crop.png` | 1024x256 | VRAM compressed | false | project default |
| `assets/vignette/hair_swept_back.png` | 1024x276 | VRAM compressed | false | project default |
| `assets/vignette/hair_textured_short.png` | 1024x268 | VRAM compressed | false | project default |
| `assets/ui/aussie_rules_dynasties_logo_placeholder.png` | 1536x1024 | lossless | false | project default |

Packed data textures that are not lossless:
- assets/vignette/figures_mask.png: VRAM compressed
- assets/vignette/figures_shade.png: VRAM compressed

**Flag for the art agent:** `figures_mask.png` and `figures_shade.png` are packed data textures (the figure shader reads them as masks and shading, not as pictures) but are imported as VRAM compressed, which is lossy. `figures_design.png` and `figures_digits.png` are lossless. Lossy compression on a mask can bleed values across edges and tint the guernsey regions; if the figures look soft or off-colour on a phone, set these two to lossless. Nothing was changed here.
