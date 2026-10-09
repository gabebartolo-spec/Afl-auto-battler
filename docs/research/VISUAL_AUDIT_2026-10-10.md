# Visual audit: how Aussie Rules Dynasties looks today, and the plan to make it beautiful

Lead agent, 2026-10-10, on main `d6aabcc0`. Director's brief: a brutally honest audit of UI, art,
colour and readability; simplicity of numbers (real football facts over simulation maths); snappy
navigation without over-designed functionality; stat-heavy screens that are beautiful, not
spreadsheets; a verdict on the vignette system; what local models and Tripo can do for the art
workflow; what to remove, what to replace, and a step-by-step plan.

The rules that come out of this audit are in [docs/VISUAL_STYLE_GUIDE.md](../VISUAL_STYLE_GUIDE.md).
This file is the evidence and the reasoning. Nothing here is implemented; every phase of the plan
is a separate assignment and a separate director look.

## Evidence

Fresh captures of every screen were taken on this PC with the project's Mobile renderer at
390x844 (phone, 1x) and 1920x1080 (PC), plus 2x crops of the figures. They are in
[visual_audit_2026-10-10/](visual_audit_2026-10-10/):

| Sheet | What it shows |
|---|---|
| [ui_phone_contact_sheet.png](visual_audit_2026-10-10/ui_phone_contact_sheet.png) | A hub, B selection, C training, D list shape, E coaching, F settings, G off-season, H draft, I player stats, J team stats, K box score, L coach break |
| [vignette_centre_bounce.png](visual_audit_2026-10-10/vignette_centre_bounce.png) | the stoppage scene at six beats, to the call |
| [vignette_prematch.png](visual_audit_2026-10-10/vignette_prematch.png) | warm-up, huddle, banner |
| [vignette_broadcast.png](visual_audit_2026-10-10/vignette_broadcast.png) | the six close-up kinds at six beats |
| [vignette_press_awards.png](visual_audit_2026-10-10/vignette_press_awards.png) | press conference, award walk-on |
| [figures_2x_crops.png](visual_audit_2026-10-10/figures_2x_crops.png) | the figures at 2x: huddle, stoppage freeze, set shot |
| [match_view_live.png](visual_audit_2026-10-10/match_view_live.png) | the live match view, twelve frames |
| [pc_1920x1080.png](visual_audit_2026-10-10/pc_1920x1080.png) | main menu, new career, hub, list on a PC window |

Earlier evidence this audit leans on: the 6 October style audit
([AFL_UI_STYLE_AUDIT_AND_RESEARCH.md](AFL_UI_STYLE_AUDIT_AND_RESEARCH.md)), the art agent's
measured animation proposal ([ANIMATION_PIPELINE_PROPOSAL.md](ANIMATION_PIPELINE_PROPOSAL.md)),
the [performance baseline](PERF_BASELINE.md), the pipeline repo's `docs/tripo_research.md`, and
today's PC captures in the lead's handoff folder.

## 1. The verdict in one paragraph

The game has a real identity waiting to come out and a template sitting on top of it. The
identity is the warm near-black page, the hand-drawn ARD Signwriter typeface, club colour as
atmosphere (the match poster, the match-day scoreboard wash), the box-score worm, the guernsey
markers, and the 2.5D footballers. The template is everything built since 8 October to answer
"not boring": a raised brown tile for every control, the club's colour poured into every selected
toggle as well as the primary action, tile grids used as navigation, and two-row tab strips.
Stacked, those make Settings, Coaching, the coach's break, Finals and the top of Team selection
look like one generic game-UI kit. The stats screens are spreadsheets. The live match view, which
a player watches longer than anything else, has no identity at all. The vignettes are the right
system with the wrong resolution and unfinished motion. None of this needs new systems; it needs
the existing ones finished with discipline.

## 2. What is good, and must be protected

- **The page.** Warm black `#121110`, off-white ink, warm greys. It is ink and evening football,
  not a SaaS dashboard. Keep every token in `UiKit.gd`.
- **The typeface.** ARD Signwriter is the single strongest identity asset in the game. Regular,
  Bold and the Display cut with its painted shade read as a ground's scoreboard and signage.
  Owned outright, built by `tools/typeface/build_font.py`.
- **Club colour as atmosphere.** `ClubDuel` and `MatchPoster` (the hub hero, the match
  scoreboard) are exactly what the director asked for on 8 October. The hub at 4K
  (lead handoff capture) is the best-composed screen in the game.
- **The box score** (K): the worm, the scoring ticks under it, the quarter grid, goalkickers in
  "4.2" notation. This is the model for every stats surface: one football fact made visual, real
  notation, no abbreviations.
- **Guernsey club markers** in the ladder, the draft log and the poster: recognisable at 22 px.
- **The coaching profile** (E, top half): label and value in plain words, "Elite / Strong /
  Average". That is how a rating should read on a primary screen.
- **Motion**: the 0.18 s ease on every screen change, count-ups and reveals. Quiet, right.
- **The vignettes' staging**: real ground dimensions through a real camera, crowd texture,
  fluoro umpire, the scoreboard in the stand, the ball, weather, pennants. At 1x on a phone it
  reads as footy.
- **The honours art**: Blender-rendered cups, flags, medals; the two Tripo pieces won the
  director's side-by-side. The trophy room is the first screen that feels like a club.

## 3. What is wrong, element by element

Severity: **S1** breaks reading or the hierarchy; **S2** makes the game look generic; **S3** polish.

### 3.1 Controls: the raised-tile monoculture (S2, everywhere)

`UiKit.style_button` gives every secondary button a raised tile: a brown fill tinted 10% toward
the club colour, a 1 px light top edge and a 3 px drop shadow. `paint_choice` fills the chosen
option solid in the club colour with a 2 px lighter border. Because nearly every control in the
game is a button, every screen is a stack of the same rounded brown rectangle:

- Settings (F): ten tiles in five pairs, five of them filled red. Red no longer means "the one
  thing to do"; it means "on".
- Coaching (E) and the coach's break (L): six plan tiles, six tag tiles, two match-up tiles,
  a "Fewer calls" tile, then two full-width tiles. On Melbourne the selected plan is the same red
  as Play match: **selection and the primary action are visually identical** (S1).
- Team selection (B): five tiles stacked before any football appears (Auto-pick, Save as my
  Best 23, One ruck / Dual ruck, Your team / Dockers, Assistant's report).
- Training (C): every player row is itself a raised tile with an outline, so a list of 37 men is
  37 buttons.
- Finals (PC capture, lead handoff): five week-name tiles where one line of text would do.
- The hub footer: four identical tiles; "Season stats" is a fifth tile floating beside the
  "Ladder" heading in a different idiom; "Settings" is plain text in the top bar. Three navigation
  idioms on one screen.

The CLAUDE.md anti-slop list already bans gratuitous shadows, pill and chip piles, and "every
section in its own rounded rectangle". The raised tile violates the first and produces the last.
The 8 October pillars (club colour as atmosphere, big type, motion, the ground's art) were
answered with more tiles instead of with composition. The pillars are right; the tile is the
wrong tool.

### 3.2 Colour: the club colour is doing three jobs (S1)

`team_colour()` is used for the primary action, for every selected choice, and for the tint in
every secondary tile. One colour, three meanings. A black-and-white club (Collingwood) falls back
to the red accent for all three, so Collingwood and the no-club Settings sheet get the orange-red
tile wall. Rule in the style guide: club colour is atmosphere and the one primary action;
selection is ink and an outline; secondary controls carry no colour.

Smaller colour findings:
- GOOD/BAD greens and reds are right and used sparingly. Keep.
- Role colours (DEF teal, MID green, RUCK gold, FWD red-orange) are legible as ink; the
  draft's role filter tiles put them on tinted boxes, which is the one place they look like chips.
- The green "Your side has: Lockdown unit" line on Selection (B) uses GOOD for information, not
  state. Information is TEXT.
- Light mode: untouched here; the 6 October appendix stands. Dark is the product.

### 3.3 Typography (S1 for the small sizes, S2 for consistency)

- ARD Signwriter is a sign-painter's face. At 16 px and above it is superb. At 12-13 px (every
  secondary line, every table header, every fine-print stamp) the strokes thin out and the
  letters crowd: "Position plan · Near his proj…" in Training is hard to read and then truncated.
  The game sets most of its metadata at these sizes. The face needs either a text cut tuned for
  small sizes (the art agent's job, a project-wide font decision for the director) or a pairing
  with Barlow (already in `assets/fonts`, OFL) for everything 13 px and under.
- The type scale (24/18/15/13/11) is declared but not obeyed: 38 calls use 14, 36 use 12, plus
  17, 20, 22, 25, 26, 28, 30 scattered through the screens. Neighbouring screens differ by a
  point or two for no reason. A lint test should fail any literal size outside the roles.
- The Draft header is a 30 px uppercase display title; every other screen has a 20 px bold
  centred title. One of them is wrong. (Display type for a screen title is good; it should be
  the rule, not the exception.)
- "INTERCHANGE" (D) and the role tabs "ALL DEFS MIDS RUCKS FWDS" (C) are all-caps labels, which
  the rules forbid.
- Line spacing in multi-line body copy (the hub's opponent notes, the off-season intro) is
  tight for a face with this much character.

### 3.4 Truncation and clipping: a football game must never cut a name (S1)

- Training rows: "At his …", "Near …", "Near his proj…" (C).
- Draft rows at 390: "Marcus Bo…", "Isaac Hee…" because the "+ MID" square gets 90 px.
- Coach's break: "Marcus Bontempe…" in a tag tile.
- Player stats: "C. Ser… FRE", "N. Dai… COL": the leaderboard cannot show a player's surname.
- Team selection summary line runs off the right edge: "Forward" clipped at 390 (B).
- The hub (A) at 390: "Ladder" heading and the table under it are cut by the footer with no
  visible scroll affordance.

The layouts give fixed-width controls priority over names. The rule must be the reverse: the
name is the one thing that never shrinks, wraps to two lines before it truncates, and controls
yield.

### 3.5 Stats screens are spreadsheets (S1, the director's explicit complaint)

Player stats (I): a dropdown, three tiles, then a table with abbreviated headers
(GM D K H K:H DE%), eight columns at 390 px, truncated names, one decimal. Team stats (J): a
guernsey icon with no club name and eight decimal columns (PF PA D MK TK I50 CL HO). This is
exactly the "number vomit" the roadmap §1.7 forbids and the opposite of the box score on the
same tab strip.

What a leaderboard is in this game: one stat at a time, chosen by name ("Disposals"); ranked
rows with rank, club marker, **full name**, club code, and one big figure in the Display cut;
"per game" as the small secondary figure; a bar or a gap to the leader where it helps a decision;
a tap opens the man. Tables with many columns exist only at PC width, and even there with words
in the header, not codes. Team stats become a club-by-club comparison of three football facts
for the chosen view (attack, defence, contest), not a matrix.

### 3.6 Navigation (S2)

- Router has a back stack and an ease; that part is snappy. Second loads are 30-40 ms.
- Season stats: five tabs in a three-row strip ("Ladder / Player stats", "Awards / Fixture",
  "Trophy room") is a layout failure, not a design.
- Finals: tile grid as a week picker.
- The hub mixes a footer row, a floating tile and a top-bar text link. On PC, the same footer row
  sits bottom-right under an empty column (fixed in #581 for the ladder column).
- Team selection puts five controls before the board. The board is the screen.
- Deep screens are fine: back always works, nothing is more than two taps from the hub. The
  problem is idiom, not depth.

### 3.7 The live match view has no identity (S1 for beauty, not for function)

The thing a player watches for minutes (match_view_live.png) is a flat green oval with ten-pixel
discs and numbers nobody can read at 390 px. It is functionally honest (the log is the truth,
the director's shapes are credible) and it is the dullest surface in the game. The club-duel
scoreboard above it is good; the pitch under it is a diagram. The token numbers are the
decoration the "no number vomit" rule warns about: they carry no information at that size.

### 3.8 Other screens

- **Hub (A):** the poster is excellent. Below it, the opponent notes are three lines of body
  copy on the page with no hierarchy; the standing card ("9th of 18 · 0-0-0 · 0 pts") is the
  right idea. The weekly-loop intro on PC is a centred modal in the club colour: good.
- **Off-season (G):** the payroll line is finance and belongs; the per-player rows are text plus
  a full-width tile each, so the list is a tile stack again. The contract facts ("76 OVR · 76 POT
  · age 31 · on $685k, wants $685k for 2 seasons") are the right facts.
- **Draft (H):** strong structure and the role-need chips ("short 6", "need 2") are genuinely
  useful information. At PC width it is the best list screen. At 390 it truncates names.
- **Club Forge:** the guernsey preview is lovely; the colour swatch grid and tile rows are the
  kit again. Acceptable.
- **Trophy room:** the first screen that feels like a club. The shelf layout at 390 leaves a
  half-empty row; fine.
- **List shape (D):** the oval is a third of the screen; names on tokens are about 9 px; the
  interchange box is a labelled rectangle. Readability fails on a phone, and at PC width
  (pc_1920x1080.png) the oval is a postage stamp in a third of the width.
- **The logo:** the placeholder PNG is better than most "final" logos, but it is a 1536x1024
  raster of unknown provenance named "placeholder". It needs either a clean vector rebuild in
  the Signwriter family by the art agent, or its provenance recorded. Nothing ships under an
  unregistered asset.

## 4. The vignette system: keep it, and finish it

### 4.1 Verdict

**Keep.** The pre-rendered 2.5D figures are the only place the game looks like a game, and the
system under them is sound: one base body, one camera, one light, deterministic renders,
per-club recolouring and designs in a shader, numbers printed by the shader, a build that fails on
mask errors, suites that check every move a scene asks for exists, CC0 body and OFL fonts. The
alternatives are worse:

| Alternative | Why not |
|---|---|
| Real-time 3D figures in Godot | throws away the mask/recolour pipeline and the tested sheet contract; doubles phone performance risk; needs a rig, LODs and lighting per scene; ARD-M8-007 already rules it out |
| Hand-drawn or illustrated figures | no per-club recolouring at this scale without a painter per club; motion consistency gone; licensing of any generated art would be the weakest link |
| Generative video or image restyling | tried and rejected: frames drift, recolouring breaks (playbook, art-consistency reference) |
| Drop the vignettes, keep the tokens | the game loses its only art; the director's §1.11 requirement is "every in-match decision requires a vignette" |

### 4.2 What is actually wrong with it

1. **Resolution.** The sheet renders at 100 px per metre; a 1.88 m man is 188 px. The stoppage
   scene draws him 1.6x larger than life (`FIGURE := 1.6`), so at 1x he is already magnified, and
   a modern phone renders the 390 px canvas at 3x. The figure the player sees is a bilinear
   sprite enlarged four to five times. The 2x crops show it: soft edges, no facial features, a
   flat ellipse for a shadow. This is the single biggest quality ceiling and no amount of pose
   work fixes it. The sheet must be rendered at 2x (200 px/m) and the scenes must draw at the
   device's pixel density.
2. **One sheet cannot grow.** Everything lives on one 2048x2668 sheet because the shader
   identifies a figure draw by its texture size and the sheet must stay under some phones'
   4096 limit. The art agent's own proposal (eight kick facings, handball, tackle, true jog,
   gather on the run, chest mark, throw-up) does not fit. Rendering at 2x makes it four times
   worse. The sheet strategy has to change: one sheet per body or per move family, the shader told
   explicitly (a uniform or a draw-colour flag) that a draw is a figure, and strips found by name.
3. **Motion.** Measured by the art agent on 7 October and still open: both feet flat with
   straight knees in the run's passing frames (the "robotic run"), the walk's foot slide, the
   ready stance hovering 8.5 cm, the ball dropping from hand to boot in 0.08-0.10 s against a
   0.2 s gravity floor, run cycles playing up to 2.7x faster than the ground covered, the gather's
   hands stopping 0.4 m above the ball. The director has already rejected the kick and the carry
   once. Motion, not modelling, is what makes these figures read as mannequins.
4. **Twins and mannequins.** The huddle (figures_2x_crops.png, left) has pairs in identical
   frames; the shared-memory rule says no two figures mirror a pose at the same moment. Faces are
   blank at every size. Hair is five overlays. A scene of 23 identical bodies with five haircuts
   reads as a chess set.
5. **Facing gaps.** A right-footer kicks only away-right; nobody kicks across the screen or toward
   the camera; the crumber's mirrored snap makes every crumber left-footed.
6. **Every scene is bespoke code.** BroadcastVignette 1011 lines, StoppageVignette 716, PreMatch
   732, AwardWinner 198, MediaConference 232. Beats, positions, timings and camera moves are
   constants in code. A new flavour scene (FL-007 authorises them) costs days and a code review
   each time, and the staging cannot be reused by the match view. The art agent's markers and
   anchors plan is the right contract; it needs a staging format on the game side to land in.
7. **Floating feet.** Soles sit a few pixels above the shadow centre in every scene (assigned to
   art on 10 October). The shadow itself is a flat ellipse with one alpha; there is no contact
   shadow under the boots, which is why the feet float even when the geometry is right.
8. **The banner.** The run-through shreds the banner into dozens of flying panels. In stills it
   reads as debris; it needs to be judged as a clip, and may need fewer, larger pieces.
9. **Press conference and awards.** Serviceable atmosphere. The media room is a grey grid, the
   journalists are silhouettes, the microphones a cluster of coloured balls; the award winner's
   number is printed on the chest. Both are "fine at 1x, cheap at 2x" and will look worse once the
   footballers are sharpened. They are the best candidates for Tripo set dressing.

### 4.3 Performance

Measured on this PC only; **no phone has ever been measured**, which is the real finding.

- VRAM: shade and mask sheets are VRAM-compressed (ASTC 4x4 on Android), about 5.5 MB each;
  the design sheet is lossless RGBA8 at full size, **21.8 MB on its own** (it went from half
  size to full size for the seams fix). Five hair atlases, the ball, the digits and nine
  512x512 honours add a few MB. Around 40 MB for figures is fine on a 2023 phone and heavy on a
  2019 one. A 2x render multiplies all of it by four unless the design sheet moves to a
  two-channel format (it carries across/up coordinates and a front/back bit: R8G8 plus a flag
  would halve it) and the sheets split so only the scene's family is loaded.
- Frame time: the match view holds 60 fps on the PC at about 200 draw calls; the first vignette
  frame costs 84 ms (shader compilation) and then 16.7 ms. The shader must be warmed at match
  load so the first close-up never hitches.
- The crowd is one texture painted once and the ground is a couple of triangle calls; that is the
  right shape for phones. Weather, flags and the banner are per-frame draws but cheap.
- Idle: nothing redraws when nothing moves. Good.
- Build-time: a full sheet build renders 254 frames across 57 strips in Blender; the pipeline
  has no per-strip cache, so every pose tweak rebuilds everything. That is the workflow cost that
  slows the art agent most.

### 4.4 Art workflow improvements

- Per-strip render cache keyed by pose, body, facing and kit hash, so a one-pose fix rebuilds one
  strip.
- The art agent's `clip_probe.py` checks (foot grounding, palm contact, joint limits, loop
  closure) promoted into the build as gates, as the proposal says. They would have failed every
  defect in 4.2.3 before anyone saw an image.
- Every build emits the review pack automatically: a contact sheet at game scale, 2x crops of
  every contact frame, and a GIF per cycle. The lead reviews that with `art-qa-critic`; nothing
  reaches the director that has not been through it.
- A staging format for scenes (who, where, which move, which frame markers, camera keys, words)
  so flavour scenes are data plus a capture, and the same data drives captures and tests.
- Reference motion from owned footage (the proposal's §9), never from text prompts, for every
  hand-and-ball move.

## 5. Local models: what they can and cannot do here

This PC: RTX 4070 SUPER 12 GB, Ryzen 9700X, 31 GB RAM, Ollama 0.40 with qwen3.5:9b (vision),
gpt-oss:20b, gemma4:26b (licence uncleared) and qwen3.6:35b coding; ComfyUI v0.39.1 in Stability
Matrix with pixelArtDiffusionXL, the pixel-art-xl LoRA and Hunyuan3D-2mv; Blender 5.2 with MPFB.
The GPU is shared with Blender renders and Godot captures, and one GPU job runs at a time.

Two probes were run today, with the models unloaded afterwards:

| Probe | Result | Verdict |
|---|---|---|
| qwen3.5:9b on the Training screenshot: list truncated strings | Found "At his …", "Near …", "Near his proj…" verbatim; invented a "double period" and a scrollbar problem | **Usable as an overflow and truncation pre-check on every capture.** Cheap, under 30 s a screen. Everything it reports is verified by a person before it is a finding. |
| qwen3.5:9b on a 2x crop of the huddle: list art defects | Named players, invented raised arms clipping torsos, a "squashed" figure and feet "raised high" that are not in the image; did find the repeated poses | **Not usable for art QC.** It describes a plausible crop, not this crop. The contact-point checks stay with the art agent's measurements and the lead's eyes. |
| gpt-oss:20b as a copy editor for six UI lines | Sensible sentence-level edits; kept "tires 25% slower" (number vomit) and added dashes; two of six rewrites were improvements | A second opinion for copy and GDScript review, never the judge. Matches the director's own 8 October comparison. |

What they are for in this project: a truncation and overflow pre-pass on capture sheets; a
copy lint (sentence case, all-caps, banned engine words, numbers with a percent sign) run over
`data/` strings and UI literals; a second review of a small GDScript change; test-idea
generation. What they are not for: judging a look, generating figure frames, deciding anything.
The diffusion models on disk are pixel-art tuned and irrelevant to this art style; SDXL base could
make concept boards or texture tiles (crowd, media-room wall, turf) but nothing shipped. Hunyuan3D
stays the free geometry fallback for props. Gemma stays off until its licence is cleared. None of
this saves Claude tokens; the value is a cheap pre-check and a fallback at usage limits.

## 6. Tripo: where it earns its credits

Checked on 10 October against the API docs and the pipeline's `tripo_research.md`:

- v3 endpoints: text, image and multiview to model; texture; convert; segment; decimate
  (retopology); rig-check; rig (25 credits); retarget to preset animations (10 credits a preset,
  biped presets idle, walk, run, jump, dive, climb, hurt, fall, turn). The P1 model is a low-poly
  generator (48-20,000 faces, about 10 s a mesh, 30-60 credits). Paid plans own the outputs with
  no attribution; free-tier outputs are CC-BY and public. Studio and API credits are separate
  wallets; the API wallet is 0, so `tools/tripo/tripo.py` cannot run until API credits are bought.
- The director has installed the Tripo Godot Bridge (uncommitted in the main checkout) and
  generated "The MCG" as a GLB: 1.97 million triangles, 67 MB, three 4K textures.

What has already been proven: props. The trophy room's cup and statuette came from Tripo and
beat the hand-built ones in the director's side-by-side. The body fit test was "a modest step up"
at phone size with the same motion problems. Text-to-motion failed a drop punt three ways.

The pipeline, in order of value:

1. **Set dressing and props through Studio, into Blender, rendered through our camera.** Media
   room (desk, backdrop, microphones, chairs), awards stage (lectern, curtains, lights), bench and
   coach's box, goal-post pads, drink carts, the interchange gate, club pennants, a premiership
   dais. Each 40-100 credits; a whole set under 3,000 against 25,000 a month. Route: Studio in the
   director's Chrome, P1 or a Smart Lowpoly retopology, FBX export, `tools/blender/cleanup_mesh.py`,
   our materials and light (as `honours.py` does), rendered to plates and strips. Nothing generated
   ships as a mesh; only renders ship.
2. **Venue plates from the MCG model.** A two-million-triangle stadium can never run in a 2D
   phone game, and the Godot Bridge drops it into the project as if it could. Its use is as a
   pre-rendered backdrop: decimate, light it with the vignette rig, render the stand from each
   vignette camera at 2x into plates that replace the painted stand band and crowd texture for
   that venue. That gives FL-003's venue atmosphere at zero runtime cost. Two cautions: a generated
   model is an impression, not the MCG, and must not be labelled with a real venue's registered
   marks; and the plates are judged by the director as a look, like any art.
3. **Preset locomotion as reference, not as output.** Retargeting a Tripo-rigged body to its
   walk, run and jump presets costs 10-25 credits and gives timing reference the art agent can
   re-key the MPFB cycles against. The rendered strips still come from the MPFB rig so masks and
   designs keep working. Try once; keep only if the reference beats the CMU clips.
4. **Not worth credits:** text-to-motion for AFL moves (proven), image-to-3D of players
   (likeness and licensing), the Godot Bridge for anything but a quick look.

Budget rule from the director's decision log: credits exist and are not the constraint; review
time is. Generate one thing, inspect it with textures off, then the next. Keep every model
private. Record each model's task id, prompt and credits in the pipeline repo's provenance file.

## 7. Remove, replace, keep

| Element | Decision | Replacement |
|---|---|---|
| Raised tile (top edge + shadow) on secondary buttons | **Remove** | flat quiet surface, 1 px rule where grouping needs it |
| Club-colour fill for a selected choice | **Replace** | selected = ink in TEXT, 2 px outline; unselected = MUTED text, no fill |
| Tile grids as navigation (Finals weeks, Season stats rows) | **Replace** | one row of underline tabs; a text picker when more than four |
| Two-row tab strips | **Remove** | never more than one row; overflow goes to a picker |
| Raised tiles as list rows (Training) | **Replace** | open editorial rows with a rule, like the full list and Staff |
| Abbreviated column headers on phone | **Remove** | one stat at a time with its name; words in headers at PC width |
| Truncated names anywhere | **Remove** | name wraps to two lines; controls yield |
| All-caps labels (INTERCHANGE, role tabs) | **Replace** | sentence case; the Display cut for emphasis |
| Literal font sizes | **Replace** | the type roles only, enforced by a test |
| Token numbers on the live oval at phone size | **Replace** | larger tokens with a readable number, or none; the carrier always named |
| Flat ellipse shadow under figures | **Replace** | contact shadow under the boots plus the soft ellipse |
| Award winner's chest number | **Remove** | caption carries the number |
| Placeholder logo PNG | **Replace or register** | vector rebuild by the art agent in the Signwriter family, or provenance recorded |
| LadderScene | **Remove** | already decided: Season stats |
| The one 2048x2668 figure sheet | **Replace** | 2x sheets split by body or move family, shader told what is a figure |
| Design sheet as lossless RGBA8 | **Replace** | two-channel lossless plus a flag |
| Scenes as bespoke code | **Replace over time** | staging data; code only for what is truly scene-specific |
| Vignettes, figures, shader pipeline, crowd, ground, camera, weather, ball, honours | **Keep** | finish them |
| ARD Signwriter | **Keep** | add a small-size answer (text cut or Barlow pairing): director decision |
| ClubDuel, MatchPoster, box-score worm, guernsey markers, Router ease | **Keep** | extend to the match view and the stats screens |

## 8. The plan, step by step

Each phase is one assignment, one PR family, and one director look with labelled captures. No
phase starts until it is assigned. Order matters: the control grammar comes first because every
later screen is built from it.

### Phase 0: control grammar v2 (UiKit only, one PR, every screen re-captured)
1. `style_button`: secondary = flat surface in PANEL, no top edge, no shadow; primary = the club
   colour (or ACCENT) fill, one per screen; danger = BAD outline. `raised()` deleted.
2. `paint_choice` and `set_selected`: selected = TEXT ink, 2 px TEXT outline, no fill;
   unselected = MUTED ink, no outline.
3. Type roles enforced: a test in `run_career_ui_tests` (or a new `ui_kit` suite) walks every
   screen's Labels and fails on a font size outside the roles; `SECONDARY` raised from 13 to 14;
   the small-size face decided by the director (text cut or Barlow pairing) before this merges.
4. Names never truncate: `UiKit.name_label()` wraps to two lines and the row's controls shrink;
   a test asserts no Label with a player or club name has `OVERRUN_TRIM_ELLIPSIS` active at 360
   and 390 widths.
5. All-caps labels removed (INTERCHANGE, role tabs). Screen titles move to the Display cut at
   TITLE size, matching the draft's intent and ending the two-title problem.
6. Captures: the twelve-screen phone contact sheet and the PC sheet, before and after, dark.
   Evidence: the ellipsis test and the type-role test shown failing first.

### Phase 1: navigation idioms (small PRs per screen)
1. Hub: footer row of four, Season stats joins it or the ladder heading becomes the link; the
   Settings link stays in the top bar. One idiom.
2. Season stats: one row of five underline tabs at 390 (short labels: Ladder, Players, Awards,
   Fixture, Trophies); the strip scrolls horizontally if a label will not fit.
3. Finals: the current week as a line of text with the other weeks as underline tabs.
4. Team selection: the board first; Auto-pick and Assistant's report in the top bar's right
   control; the ruck and side toggles as one text line each.
5. Coach's break: plan and tag as single-row segmented choices (text with underline), the
   match-ups as editorial rows with a "Change" text action; one primary "Start quarter".

### Phase 2: stats as leaderboards (Season stats)
1. Player stats: the leaderboard row described in 3.5; the stat picker stays; "Totals / Per
   game" becomes one toggle; Filters becomes a sheet. PC width adds the multi-column table with
   words in the header.
2. Team stats: club name and marker, three facts per view (Attack: points for, inside 50s,
   goals a game; Defence: points against, tackles, rebound 50s; Contest: contested ball,
   clearances, hit-outs), a bar against the league's best, no decimals unless the stat is a rate.
3. Box score unchanged; its worm becomes the model for a season form strip on the ladder.
4. Evidence: the stats suite's existing floors plus a capture of every section.

### Phase 3: the live match view gets an identity
1. Tokens at phone size: at least 18 px, club colour with the club's design hint (a stripe, a
   hoop, a sash) in the disc, the number dropped when the disc is under 18 px; the carrier and the
   ringed players named; a short ball trail.
2. The oval: a vignette of shadow at the boundary, the stand edge drawn as a band, the mown
   stripes kept; the scoreboard wash already there.
3. A prototype only, gated by the director's phone: mini figures (a 24 px facing set from the
   same pipeline) for the six players around the ball. If it reads and holds 60 fps on the
   director's phone, it becomes the view; otherwise the token design stands.

### Phase 4: the vignette system, finished (art agent leads, lead builds the game side)
1. Sheet contract v2: 2x render (200 px/m), sheets per body or move family, the shader told
   explicitly which draws are figures, the design sheet in two channels plus a flag, strips found
   by name; the game draws at device pixel density. Assets suite extended to the new layout.
2. Shader warm-up at match load (draw one hidden frame of each material) so the first close-up
   never costs 84 ms.
3. Motion: the proposal's phases A (markers and anchors, probe checks as gates), B (locomotion
   re-keyed from reference, true jog, foot plants), C (gather on the run, carry, 7-frame drop punt
   with a 0.2-0.3 s drop, right-footed at five facings). Each as before/after at 2x for the
   director.
4. Contact shadows under boots; no twins (a scene never shows two figures on the same frame of
   the same move at the same moment; the suite checks it).
5. Staging data for scenes: beats, positions, moves, markers, camera keys and words as a
   dictionary per scene; PreMatch and Stoppage ported first; new FL-007 scenes authored in data.
6. Venue plates (Tripo MCG and any other venue the director wants) rendered through the vignette
   rig at 2x; the painted stand stays as the fallback for venues without a plate.
7. Media room and awards stage dressed with Tripo props rendered through the same rig.
8. The first phone measurement: an Android build on the director's phone with the frame-time
   probe, before and after 4.1. This is a gate for everything above.

### Phase 5: Tripo props batch (art agent, Studio credits)
One prop at a time per the budget rule; each rendered through our rig, judged in the game, not in
Tripo's viewer; provenance recorded.

### Phase 6: QA automation (support and lead)
1. `capture.yml` runs on every PR that touches `scripts/ui`, `assets/vignette` or the pipeline
   install, producing the phone contact sheet, the PC sheet, 2x crops of every figure scene's
   contact frames, and a clip for anything that moves.
2. The local vision model's truncation pre-pass runs over the sheet locally before the lead's
   review; findings are verified by eye.
3. Every art PR's review pack goes to the lead first (shared-memory rule), and only a passing
   pack reaches the director as one decision with labelled images.

## 9. Decisions for the director

**Answered 2026-10-10 (director, in the lead's session):** order: both streams in parallel (the
lead builds the UI phases, the art agent starts the 2x sheet contract); match view: token identity
now, mini-figures as a prototype gated by the director's phone; Tripo: media room and awards stage
props first, the venue plate after; Phase 0 assigned to the lead now, with the small-size type
(Barlow pairing or a text cut) and the selection treatment shown as A/B captures on real screens in
its first review. The questions as asked are kept below for the record.

**Answered 2026-10-10 (director, Phase 0 review, PR #584):** 9.1 small-size type = **A, ARD
Signwriter at every size** (one family; the Barlow pairing rejected and removed from UiKit);
9.2 selection = **A, ink and a 2 px outline** (the faint club tint rejected and removed).
Boards in `agent-handoffs/lead/phase0/`.

These are taste or trade-off calls; everything else above is objectively good and proceeds when
assigned.

1. **Small-size type:** a text cut of ARD Signwriter drawn for 12-14 px (slower, one family), or
   Barlow for everything 13 px and under (immediate, two families). Recommended: Barlow now,
   text cut when the art agent has time, judged on the Training and Player stats rows.
2. **Selection colour:** ink and outline (recommended), or a faint club tint behind the chosen
   option. Shown on Coaching and Settings side by side.
3. **The match view:** token identity now with the mini-figure prototype gated by the phone
   (recommended), or straight to mini figures.
4. **Venue plates from Tripo:** build the MCG plate as the first venue (recommended), or keep the
   painted stand and spend Tripo on the media room and stage first.
5. **Order:** phases 0 to 2 before any vignette work (recommended: the player sees the UI every
   minute, the vignettes a few seconds a match), or phase 4 first.
