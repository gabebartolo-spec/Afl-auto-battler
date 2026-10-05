# Vignette art inventory (ARD-M8-007 art-style replacement)

Every player-facing scene that draws people, as of `main` at 4b715b7 (2026-10-06), and whether it still uses the old style. This is the checklist for the art-style replacement in ARD-M8-007 ("Complete vignette art-style replacement - director requirement, 2026-10-05").

The new style is the pre-rendered 2.5D figures: `VignetteFigures.gd` plus `assets/vignette/figures_*.png`, drawn through `figure.gdshader`, built by `ard-asset-pipeline`. The old style is figures drawn in code: line limbs, a polygon torso, a dark circle head.

**Status values:**
- **TODO** - still drawn in the old style.
- **NEW** - uses the new figures; awaiting the director's review.
- **N/A** - not a vignette.

None is DONE until the director has reviewed it.

## Scenes that draw figures

| # | Scene (file) | Reached from | Who is shown | Figure art | Status |
|---|---|---|---|---|---|
| 1 | Centre-bounce close-up (`match/StoppageVignette.gd`) | MatchSim's centre-bounce call (`bounce_attendees`); every match with the playtest switch | Both clubs' ruck and on-ballers from MatchSim, plus the umpire | Sprites: idle, jog, leap, bounce; front and back. No fallback path. | NEW |
| 2 | Pre-match run-through (`match/PreMatchVignette.gd`, extends 1) | Play match, while the round is prepared | Your first 9 on the ground, their first 6 | Sprites, through `StoppageVignette._draw_figure`. The banner and fence are drawn shapes, not people. | NEW |
| 3a | Speccy mark: front, side and defensive (`match/BroadcastVignette.gd` `_draw_speccy`) | `pick_kind`: a `speccy` mark with 3 or more nearby | The marker (number, club) and 2-3 opponents in the pack | Old: `_draw_player` silhouettes, arms raised for the mark | TODO |
| 3b | After-siren set shot (`_draw_after_siren`) | `pick_kind`: a Q4 set shot, then the final siren, margin 6 or less | The kicker (number) | Old: a running silhouette | TODO |
| 3c | Goal-line crumb (`_draw_goal_line`) | `pick_kind`: an event with `crumb` (the #229 sequence) | The crumber (number), the forward and defender in the marking contest, a lunging defender | Old: 5 silhouettes, the pack with arms up | TODO |
| 3d | Boundary snap (`_draw_boundary_snap`) | `pick_kind`: a general-play score from the pocket | The kicker (number) | Old: one silhouette | TODO |
| 4 | Award walk-on and medal (`match/AwardWinnerVignette.gd`, extends 3) | Season awards ceremony (`SeasonAwards.gd`), each single-winner award | The winner: club colours and jumper number | Old: `_draw_player`, walking in, arms up from 1.8 s; medal drawn on the chest | TODO |
| 5 | Post-match press conference (`MediaConferenceVignette.gd`) | Hub, after a match (ARD-M6-008) | Your coach at the desk; three journalists' heads in the foreground | Old style, not footballers: the coach is a rectangle shirt and a skin-coloured circle head; the journalists are dark circles | TODO, scope to confirm |

## Not vignettes (out of scope)

- **`PitchView.gd`** and **`FormationView.gd`** draw players as round club-colour tokens on the top-down oval and the formation board. That is the standard watched-match view and the selection board, which ARD-M8-007 says it does not replace.
- The scoreboard, banners, crowd bands, goalposts and ball are scene dressing, not figures. They stay drawn in code.

## Fallbacks and old paths

- **`BroadcastVignette._draw_player`** is the only old figure renderer that footballers still use. It's called by 3a-3d and by 4 through inheritance. Delete it once 3 and 4 are migrated.
- **`MediaConferenceVignette._draw_coach`** is a second old renderer, used only by 5.
- **The sprite scenes (1, 2)** have no fallback. If the sheet failed to load, nothing would be drawn, rather than the old silhouettes.
- **Review tools:**
  - Scenes 1 and 2 already have one each (`tools/visual/capture_vignette.gd`, `capture_prematch.gd`).
  - Scene 4 has `capture_awards.gd`.
  - Scene 3 has none yet. The migration adds one that renders each of 3a-3d at its beats, at 360 and 412 px portrait.

## What each migration needs from the figure sheet

The sheet now holds two bodies (average, ruck) with idle, jog, leap and bounce, front and back. Positions, timings, `pick_kind` and `DURATIONS` don't change. Only the figure drawing does.

| Scene | Moves needed | Already on the sheet | To render |
|---|---|---|---|
| 3a speccy | Leap and mark; pack players leaping or standing | leap, idle | None. Optionally a held-mark frame with the ball in both hands. |
| 3b after siren | Run-up, ball drop, kick, follow-through | jog | **kick** (about 6 frames), back view so the number shows |
| 3c goal line | Pack leap and spoil; the crumber runs, gathers off the deck and snaps; a defender lunges | leap, jog | **gather** (about 3), **snap** (about 5), **lunge** (about 3) |
| 3d boundary snap | Snap from the pocket | - | **snap** (shared with 3c) |
| 4 awards | Walk on, stand, then arms up with the medal | idle; arms up is the top leap frame | **walk** (about 8), **celebrate** (1-2: standing, arms up) |
| 5 press conference | A seated coach in a club polo behind the desk; journalists from behind | none | A non-footballer outfit (polo with sleeves, no shorts or socks) on the same body: a new kit layout in the pipeline. The journalists are back-view figures in plain dark clothes. |

**Sheet size:** the new moves would push the sheet past 4096 px. That's over some phones' texture limit, and `SHEET_SIZE` also identifies figure draws to the shader. The new moves go on the average body only (the ruck needs only idle, jog and leap), with a repack, or on a second sheet. I'll decide that in the first migration PR.

## Migration order (one family per PR)

1. **Broadcast (3a-3d)**, with the new kick, gather, snap and lunge moves and a broadcast capture tool.
2. **Awards (4)**, with walk and celebrate. Retire `_draw_player`.
3. **Press conference (5)**, if confirmed in scope, with the coach outfit. Retire `_draw_coach`.

Each PR includes:
- Phone stills at 360 and 412 px portrait.
- `match_visual` and `matchday` suite runs.
- A [MERGE NOTE] comment.
- No status marked DONE.

## Open questions for the director

- **Press conference (5):** it's a hub scene, not a match moment, but it uses the old procedural figure language. Is it in scope? I think yes: it's the last drawn person in the game.
- **Extras' looks:** the extras in broadcast scenes (pack players, the lunging defender) aren't named by MatchSim. Should they take a neutral look (`Appearance.UNCURATED`) or a generated one? I recommend neutral: a real player is never implied.
- **Award winner's number:** the winner faces the camera. Real guernseys carry the number on the back, but today's scene prints it on the chest. Keep a chest number, or drop it from the figure and rely on the caption?
