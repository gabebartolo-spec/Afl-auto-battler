---
name: afl-art-pipeline
description: How the vignette footballers are made and what a code agent may change about them - the MPFB -> Blender -> sheet -> Godot pipeline, the sheet contract, compression, the mask checks, the save contract for player looks and the director's appearance gate. Use it whenever you touch assets/vignette/ (figure sheets, figure.gdshader), scripts/ui/match/VignetteFigures.gd, the vignette scenes' figure drawing, Appearance.gd or data/player_appearance.csv, Club Forge looks, or the ard-asset-pipeline repo - even for a "one-line" change.
---

# The art pipeline (vignette figures)

The vignette footballers are pre-rendered, recoloured at draw time, and owned
by the art agent. The detail lives in the pipeline repo, `../ard-asset-pipeline`
(github.com/gabebartolo-spec/ard-asset-pipeline); its README is the reference.

## How a sheet is made

MPFB body (`body_types.json`) -> kit regions and poses (`ard_body.py`,
`poses.py`) -> EEVEE renders (`build_sprites.py`) -> checked and packed
(`pack_sprites.py`) -> one sheet set plus `VignetteFigures.gd`
(`combine_sheets.py`). From the pipeline repo, in the background:

```bash
./build_vignette_figures.sh --install ../Afl-auto-battler-<your worktree>
```

It builds every body (average, ruck, small, coach) and the number atlas, and
copies them to `assets/vignette/` and `scripts/ui/match/`. Then re-import in
Godot, run `matchday`, `match_visual` and `assets` (see afl-godot-tests), and
capture with `tools/visual/capture_vignette.gd` or `capture_broadcast.gd`.

## The sheet contract

- `VignetteFigures.gd` is **generated**. Never edit it by hand: rebuild. Its
  header documents every channel of `figures_shade`, `figures_mask` and the
  half-size `figures_design`; numbers come from `figures_digits.png`.
- Moves are **strips** (`BODIES[body]["anims"][anim][facing]`: `x`, `y`,
  `size`, `frames`, feet `pivot`, per-frame `reach`), and strips differ in
  size. Find frames with `VignetteFigures.strip()` and `source()`, never with
  hard-coded rectangles.
- `SHEET_SIZE` changes whenever moves are added. The shader recognises a
  figure draw by its texture size, so pass `VignetteFigures.SHEET_SIZE` to the
  `sheet_size` uniform, as StoppageVignette does, and never type the number.
- A scene plays only the moves the sheets hold (the suites check this). A new
  move is an art request, not a code change.

## Compression budget (#284)

`figures_shade` and `figures_mask` are **VRAM Compressed, High Quality**:
ASTC 4x4 on Android, BPTC on desktop. `figures_design` stays **lossless**,
because compressed, its hoops go wavy and the numbers shred. **Never ETC2**
(plain VRAM Compressed on Android): the stripes break into blocks. The set was
about 19.5 MB of GPU memory at #284's 2048 x 3168. Growth past that needs the
art agent's measurement and the director's phone check. A code PR never
changes a figure sheet's `.import`.

## Build-time checks (pack_sprites.py)

A build stops if:
- the weights on a covered pixel sum to more than 1;
- the guernsey weight leaves the base colour, or sits more than **1 px**
  outside the figure (only the anti-aliased rim is allowed; a mask from
  another render fails);
- a frame is empty;
- a figure touches its frame's top or sides (clipped).

Colour is bled into the transparent pixels around each figure. If the game's
figure checks fail after an install, rebuild; never patch the PNGs.

## Samples first, at game scale

A change to how figures look starts as a sample: a capture at the size the
game draws figures, beside the current look, a 2-2.5x close-up, and a GIF
where it moves. The full rebuild comes after the director has seen it.
Blender close-ups are the art agent's own review, not proof of the game.

## The director's appearance gate

The director approves every look: figures, poses, kit drawing, skin tones,
hair, Club Forge options and markers. Green CI is not approval, and nor is a
teammate's "looks fine". A PR that changes how figures look stays a prototype
until the director has seen it in the game, with the pictures in the same
message as the question. Approval of a contact sheet is for the shape, not
the in-game build.

## Save contract for player looks (Appearance.gd)

- Skin and hair colours are **palette indices** (0-5) into `Appearance.SKIN`
  and `HAIR`. Reordering or removing an entry breaks saves and the curated CSV:
  add at the end, with the director's approval.
- Everything else is a **string id** (`hair_style`, `beard`, `boots`,
  `socks`...). A save never stores a sheet position or frame index.
- When styles reach the sheets, the pipeline **generates** the id -> sheet
  index table beside `VignetteFigures.gd`. Code reads it; nobody maintains one
  by hand. An id with no art yet draws the base look.
- Looks are presentation only: never read by the sim, never inferred from a
  name. A real player shows his curated row or the neutral look, never a guess.

## What a code agent may and may not touch

- **May:** place, time, mirror and tint figures through `VignetteFigures`; add
  scene logic and data (club colours, `data/clubs.csv` designs); read
  `Appearance`; add tests; capture review images.
- **Ask the art agent first:** new moves, poses or facings; channel meanings
  or the shader's colour logic; any sheet, atlas or `.import` change; new skin,
  hair or style options; anything a player would see differently.
- **Never:** hand-edit `VignetteFigures.gd` or a `figures_*.png`; hard-code
  frame rectangles or `SHEET_SIZE`; ship an unapproved look.
