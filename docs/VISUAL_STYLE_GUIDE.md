# Visual style guide: the look of Aussie Rules Dynasties

The rules for how this game looks. Written for the agents who build it (Claude, the art agent)
and decided by the director. It replaces nothing in CLAUDE.md; it makes those rules concrete
enough to build from and to test against. The evidence and the reasoning are in
[docs/research/VISUAL_AUDIT_2026-10-10.md](research/VISUAL_AUDIT_2026-10-10.md). When this
guide and a screen disagree, the screen is wrong. When this guide and the director disagree, the
director is right and this guide changes.

The one test, from CLAUDE.md: without the AFL names and logos, would the screen still look like
this game? If it could belong to any sports-management app, it has drifted.

## 1. Identity in five sentences

1. The game is a football club's evening: a warm near-black page, ink type, the club's colours as
   the light in the room.
2. Its voice is the hand-painted scoreboard and signage of a suburban ground: one typeface, drawn
   for the game, carries every word and figure.
3. Football facts are shown as a coach would say them, in words first and in a figure only when
   the figure is the point.
4. The people and the ground are the art: pre-rendered footballers in real club kit on a ground
   drawn to real dimensions, never diagrams dressed up.
5. Everything else is quiet. One hero element per screen, one decision per screen, the rest
   earns its place by being read.

## 2. Tokens (UiKit.gd owns these; screens never invent a colour or a size)

### 2.1 Colour

| Token | Dark | Job |
|---|---|---|
| BG | `#121110` | the page |
| PANEL | `#1b1a17` | a grouped surface; no border, RADIUS corners |
| PANEL_ALT | `#24221e` | a surface on a surface; rare |
| INK | `#0d0c0b` | inputs and wells |
| LINE | `#363229` | rules and outlines |
| TEXT | `#f1eee6` | every ordinary word and figure |
| MUTED | `#a39e93` | the line under a name, metadata, inactive tabs |
| FAINT | `#6e695f` | disabled only |
| GOOD / BAD | `#8cc49a` / `#e38b73` | a genuine state (form, injury, over the cap); never information, never decoration |
| ACCENT | red | the primary action when no club colour applies (main menu, Settings) |
| Club colour | per club, `team_colour()` | atmosphere and the one primary action; see 2.2 |
| Role colours | DEF teal, MID green, RUCK gold, FWD red-orange | as ink only, in a fixed-width column; never a box |

Light mode is maintained, not designed for. It uses dedicated pairs, never inverted tokens.

### 2.2 Where colour goes

- **Atmosphere:** the club's colour as a wash (ClubDuel, MatchPoster, the match scoreboard), a
  gradient from the club colour to the page at the head of a screen, a 2 px club rule under a
  heading, the club's guernsey marker. Both clubs on match day. This is where "not boring" lives.
- **The primary action:** one button per screen, filled in the club colour (ACCENT when there is
  no club), white or near-black ink by luminance. Never two filled buttons on one screen.
- **Selection:** TEXT ink and a 2 px TEXT outline on the chosen option; MUTED ink and nothing
  else on the rest. Selection is never a fill and never the club colour, so a chosen option can
  never be mistaken for the thing to do next.
- **State:** GOOD and BAD only when the game is telling the truth about a state that changed.
- **Everything else:** TEXT, MUTED, PANEL. Surfaces carry no colour.

### 2.3 Type

The face is ARD Signwriter (Regular, Bold, Display with its painted shade). The roles are the
only sizes a screen may use; literal sizes are a defect and a test fails them.

| Role | Size | Face | Use |
|---|---|---|---|
| TITLE | 24 | Display | the screen's title or its one big fact; shade on |
| HEADING | 18 | Bold | a section |
| NAME | 16 | Bold | a player or club leading a row; button text |
| BODY | 15 | Regular | sentences |
| SECONDARY | 14 | Regular, MUTED | the line under a name |
| FINE | 12 | Regular, MUTED | stamps and fine print only, never a fact the player decides on |
| RATING | 30 | Display | a rating as a figure |
| SCORE | 24 | Display | a match score |
| NUMBER | 22 | Display | a figure in a list row |

Small sizes: ARD Signwriter is a sign face and thins out under 14 px. Until the director chooses
between a text cut of the family and a Barlow pairing for SECONDARY and FINE, SECONDARY is 14 and
nothing the player decides on is set in FINE.

Rules: sentence case always, except AFL conventions (OVR, POT, Grand Final, club codes); no
letter-spacing; no all-caps labels; digits in tables are tabular; the Display cut is for scores,
ratings, titles and the "v" between two clubs, never for body copy.

### 2.4 Space and shape

- GAP 8 between rows; SECTION 18 between sections; page gutter 16 on a phone, 12 inside a
  sheet, 10 around the oval only.
- RADIUS 6, nothing rounder. Panels have no border. Rules are 1 px LINE.
- No drop shadows, no top-edge highlights, no glows, no glassmorphism, no gradients except the
  club wash in 2.2.
- Thumb targets are at least 44 px tall; a scrollbar rail is 20 px wide with a 6 px thumb.

## 3. Components: the whole kit

What exists and when to use it. If the kit lacks something, the answer is usually typography or
a rule, not a new component.

| Component | Looks like | Use |
|---|---|---|
| Primary button | club-colour fill, bold NAME text | the one action; last in the column, where the thumb is |
| Secondary button | flat PANEL surface, TEXT text, no outline, no shadow | other actions; at most three visible |
| Danger button | BAD outline and text | release, delete, reset |
| Text action | bold TEXT, no surface (`UiKit.text_action`) | "Change", "Undo", "Skip to full time", "Assistant's report ›" beside a fact |
| Section link | a heading whose row is the way in: title left, "Season stats ›" MUTED right (`UiKit.section_link`) | a section that opens a whole screen |
| Choice (grid) | options outlined when chosen, TEXT ink; rest MUTED on the quiet surface (`UiKit.choice_grid`) | plans, names, anything with long labels or more than five options |
| Choice (segmented) | one line of short words, the current one underlined (`UiKit.segmented`; `UiKit.strip` if it must scroll) | two to five short options: One ruck · Dual ruck, Composed · Fire them up · Calm them, finals weeks |
| Tabs | text with a 2 px underline under the current one, one row only (`UiKit.tab`) | sections of a screen; more than five means a picker |
| Picker | a flat INK field with a chevron | choosing one of many (a stat, a venue) |
| Editorial row | name in NAME, secondary line under it, figure at the right in NUMBER, 1 px rule | every list of people or clubs |
| Leaderboard row | rank, club marker, full name, club code, one Display figure | stats |
| Panel | PANEL surface, no border | real grouping only |
| Club marker | the club's guernsey, 22 px; code on the chest from 32 px | wherever a club is named in a row |
| Trait line | "Ball magnet · Big-game player" in SECONDARY, Hothead in BAD | a player's traits |
| Role tag | role code in its colour, fixed-width column | lists |
| Figure | Display cut, shade on | a score, a rating, a position ("9th") |
| Poster / duel | ClubDuel wash with both clubs | the hub hero, the match scoreboard, a final |
| Top bar | back glyph, TITLE centred, one right control | every screen below the hub |
| Sheet | PANEL over the screen, Done as the primary | settings, a player, a filter |

Banned: raised tiles, pills, chips, badges, progress bars for anything but a genuine progress,
icon rows, stat boxes, cards inside cards, a tile grid used as navigation, two-row tab strips,
decorative dividers, any control whose only job is to look like a control.

## 4. Screen templates

Every screen is one of these. A screen that is none of them is probably two screens.

### 4.1 Hub (home)
Order: the hero (match poster), the two or three facts that matter this week in BODY, the
decision (Pick the side, Play match), your standing (one Display figure and a line), one row of
four navigation buttons pinned at the foot. Settings in the top bar. Nothing else on the first
viewport. Quiet weeks look quiet.

### 4.2 List (people or clubs)
A title, one line of context, one row of tabs or a segmented filter, a search field when the
list is longer than a screen, then editorial rows. The name never truncates: it wraps to two lines
and the controls yield. Long-press for multi-select; tap for the sheet. On PC width the row gains
columns, never a second visual grammar.

### 4.3 Board (selection, shape)
The board first and biggest. Names on tokens must be readable at 390 px or the token shows a
number and the name goes in a line below the board. Controls after the board; the primary action
last.

### 4.4 Decision sheet (coach's break, contract, event)
What happened in two lines, the choice as a segmented control or at most three secondary buttons
each with a one-line consequence in plain words, one primary action. No numbers unless the number
is the decision (a cost, a term).

### 4.5 Leaderboard (stats)
A picker for the stat, one toggle (totals or per game), then leaderboard rows. One stat at a time
on a phone. PC width may show a table with words in its header. Team comparisons show three facts
per view with a bar against the league's best. The box score's worm is the model: one football
fact made visual, real notation ("4.2"), no abbreviations.

### 4.6 Match (live)
The club-duel scoreboard, the oval, one line of your plan, the transport. The oval has an
identity (PitchView, since #598): tokens are discs in the club's home kit (base colour, the design
in the pattern colour), never under 18 px, the number in white with a dark edge or dropped; the
carrier and your ringed players named under their tokens; a short ball trail; the stand beyond a
fence band and the turf's edge in shadow. Overlays (breaks, calls, close-ups) use the decision
sheet and the vignette rules.

### 4.7 Occasion (awards, trophy room, finals, off-season wrap)
Club colour as a full wash, the Display cut big, the honours art large, one thing happening. A
skippable, readable culmination.

## 5. Copy

- Write what a coach, recruiter, commentator or supporter would say. No engine words
  (modifier, coefficient, roll, tick).
- A number appears only when it helps the player understand or decide: a score, a rating, a
  contract, a ladder position, a margin. A percentage appears only as a real football rate
  (disposal efficiency, accuracy). A simulation effect is described in words ("tires late",
  "wins more clearances, concedes more if they get out"), never as a multiplier.
- Every line is scrutable: the player can see the effect it names.
- Sentence case. Short. Nothing repeated that context already shows.
- Labels name football things: Ladder, Players, Awards, Fixture, Trophies; never "Analytics",
  "Dashboard", "Stats hub" on a screen.

## 6. Motion

- A screen eases in over 0.18 s; a headline reveals; a figure counts up to its real value in
  under a second; nothing bounces, slides from the side or shakes except the approved match
  haptics and shake.
- Headless runs (tests, captures) see the final state at once (`UiKit.motion_on()`).
- Motion in the vignettes is judged as a played clip at game speed, never from stills.

## 7. Art: the figures, the ground, the occasions

### 7.1 Figures
- Pre-rendered from the MPFB base body through the pipeline repo; recoloured per club and
  player by `figure.gdshader`; numbers printed by the shader; hair as overlays. Code never edits
  a sheet or `VignetteFigures.gd`.
- Render resolution is 2x the drawn size on a 1x canvas (200 px per metre); scenes draw at the
  device's pixel density. A figure is never magnified more than 1.5x on screen.
- Sheets are split by body or move family; a draw is identified to the shader explicitly, not by
  texture size; strips are found by name.
- Every strip carries its contact markers (foot plants, ball release, ball contact, gather, mark,
  tackle), its ball anchors per frame, its rendered side and its timing limits. Scenes read them;
  nothing is hand-measured in code.
- Grounding: a planted foot is within 1 cm of the turf; a contact shadow sits under the boots;
  the soft ellipse is secondary.
- No twins: two figures are never on the same frame of the same move at the same moment; idle
  figures watch the play.
- A kick's foot matches the player; a mirrored kick is a left-foot kick and nothing else.
- Faces stay unlikenessed; real players show their curated row or the neutral look, never a
  guess.
- Any change to how figures look starts as a sample at game scale beside today's, with a 2x
  crop and a clip, through the lead's QC, then the director.

### 7.2 The ground and the crowd
- Real AFL dimensions through the scene's camera; posts, square, arcs, circles, mown stripes,
  apron, fence, stand. Both clubs' colours in the crowd and on the boards.
- Venue plates (pre-rendered backdrops from the vignette rig) replace the painted stand where a
  venue has one; the painted stand is the fallback. A plate is an impression of a ground, never a
  labelled copy of a real venue's marks.
- Weather is restrained: it never covers the ball or a name.

### 7.3 Occasions
- Media room, awards stage, trophy room: dressed with props rendered through the same camera and
  light (Blender, with Tripo for sculpted shapes); never a runtime mesh.
- Honours art is the Blender set in `assets/honours`, one framing, one light.

### 7.4 Scenes
- A scene is staging data (beats, who, where, which move, which markers, camera keys, words)
  plus a capture tool; code only for what is truly scene-specific.
- Every scene plays only moves the sheets hold; a new move is an art request.
- Presentation reads the match log and changes nothing.

## 8. Licences and provenance

- Fonts: SIL OFL or owned (ARD Signwriter), licence file beside the font.
- Figures: MPFB base (CC0), our renders. Props: our Blender files, Tripo on a paid plan (owned,
  private), rendered only; Hunyuan3D as geometry reference. Motion: owned footage, CMU, Tripo
  presets as reference.
- Banned: non-commercial models (Qwen-Image 2.1, Anima, GVHMR, free DeepMotion, QuickMagic,
  Cascadeur free), broadcast footage as derivation, any likeness.
- Nothing ships without a row in the pipeline repo's provenance file: source, licence, task id,
  credits.

## 9. Tools and what they are allowed to do

| Tool | Allowed | Not allowed |
|---|---|---|
| Blender + MPFB (pipeline repo) | every shipped figure, prop render, plate, honour | nothing |
| Tripo (Studio, director's Chrome; API when credits exist) | sculpted props, venue impressions, locomotion reference; one at a time, private | player bodies as a shortcut past motion, text-to-motion for ball skills, shipping a mesh |
| ComfyUI / SDXL (local) | concept boards, texture tiles to be repainted, mood references | figure frames, anything shipped |
| Hunyuan3D (local) | geometry reference for props | shipped meshes |
| Ollama text models | copy lint, a second review of a small change, test ideas | judging a look, writing code that lands unreviewed |
| Ollama vision model (qwen3.5) | a truncation and overflow pre-pass on capture sheets, verified by eye | art QC of any kind |
| Godot capture tools, capture.yml | every review image and clip | nothing |

## 10. Proof: what every visual change ships with

- The before/after at the sizes the game is played at: phone 390 (and 360 when a layout
  changes), PC 1920x1080 and 4K when a wide layout is touched; dark first, light when touched.
- 2x crops of anything with contact points; a clip for anything that moves.
- The right art loaded, proven (not a fallback).
- A real tap on any new or changed touch flow.
- Tests: no literal font sizes; no truncated names; every move a scene asks for exists on the
  sheet; the figure checks; the floors.
- The lead's `art-qa-critic` pass before the director sees anything; one decision per question,
  recommended option first, labelled images sent in the same turn.
- Green CI is not approval of a look. The director approves a look in the game, on a device.

## 11. Decisions this guide still needs from the director

All answered on 2026-10-10 and recorded in the audit §9: ARD Signwriter at every size (no
Barlow pairing); selection is ink and a 2 px outline (no club tint); the match view keeps tokens,
now in each club's kit, with mini figures only as a prototype on the director's phone; venue plates
after the media room and stage props; UI phases first. New taste questions go to the director as
A/B captures, one decision per question.
