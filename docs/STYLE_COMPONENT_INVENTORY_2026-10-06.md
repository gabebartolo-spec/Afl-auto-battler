# Dark-slice component inventory (STYLE-01/02/03 prep, 2026-10-06)

Where buttons, rows, label roles and score styles are built, and where screens
build or override them locally. The purpose is to land the art agent's
approved treatment in one place (`scripts/ui/UiKit.gd`) instead of screen by
screen. Read from `main`; doc only, no changes.

## What UiKit already owns

- **Buttons:** `style_button` (the one place a button's styleboxes and font
  colours are set), `btn`, `danger_btn`, `tab`, `set_selected`,
  `paint_choice`/`choice_grid`, and `option`.
- **Surfaces:** `style` (StyleBoxFlat), `panel`, `rule`, `cover`/`modal_box`,
  and the scrollbar (`scroll`, `style_scrollbar`).
- **Labels:** `lbl`, `line`, `ellipsis`, `heading` (H1), `title`, `section`,
  `subtitle`, and `figure` (the DISPLAY condensed face, for numbers and scores).
- **Type scale:** H1 24, H2 18, BODY 15, SMALL 13, TINY 11. Fonts: FONT, BOLD
  (Barlow) and DISPLAY (Barlow Condensed Bold).
- **Chips:** `chip`, `role_chip`, `trait_chips`; club marks: `club_marker`,
  `club_badge`; tables: `ladder_table`.

**Buttons are already centralised.** Screens make 132 `UiKit.btn` calls and
only 11 local `Button.new()`, and no screen calls `style_button` on its own
button. A treatment applied in `style_button`/`set_selected`/`tab` reaches
nearly every button.

## Where screens build or override locally

| file | local `Button.new()` | local `StyleBoxFlat` | stylebox overrides | font-colour overrides | font-size overrides | other |
|---|---|---|---|---|---|---|
| DraftScene.gd | 2 | 0 | 5 | 5 | 0 | 1 literal hex colour |
| CoachingScene.gd | 3 | 0 | 3 | 2 | 1 | |
| ListScene.gd | 1 | 1 | 2 | 0 | 0 | |
| StaffScene.gd | 2 | 0 | 1 | 0 | 1 | 1 font override (BOLD) |
| match/PlayerStatsTable.gd | 2 | 0 | 0 | 1 | 1 | |
| SelectionScene.gd | 1 | 1 | 1 | 0 | 0 | |
| Main.gd | 0 | 0 | 1 | 3 | 0 | |
| HubScene.gd | 0 | 0 | 1 | 1 | 1 | |

That's 11 local buttons, 2 local styleboxes, 14 stylebox overrides and 12
font-colour overrides in eight files. They're the places an approved button
or row treatment would miss. Each should either call `UiKit.style_button`/
`set_selected` or gain a named UiKit helper (for example a "list row"
builder) that the treatment lives in.

## Type roles: the main dispersion (STYLE-02)

UiKit's scale has five sizes, but screens pass **16 distinct literal sizes**
to the UiKit builders, in about 245 calls, against 80 calls that use the named
constants:

| size | calls | | size | calls |
|---|---|---|---|---|
| 11 | 8 | | 17 | 20 |
| 12 | 37 | | 18 | 7 |
| 13 | 48 | | 19 | 3 |
| 14 | 50 | | 20 | 7 |
| 15 | 31 | | 22–30 | 17 |
| 16 | 32 | | | |

Named: SMALL 35, BODY 26, H1 13, H2 6. Heaviest literal users: DraftScene
(29), TrainingScene (18), SeasonReviewScene (12), OffseasonScene (11),
HubScene (9), MatchScene (7).

STYLE-02 should define named roles (for example name, secondary, rating,
stamp, section, display score) in UiKit and map the literal sizes to them.
12, 14, 16 and 17 have no named equivalent today. An approved typography
treatment can't land in one place until this mapping exists. It's mechanical
work once the roles are approved.

## Scores and drawn text (STYLE-02/03/04)

- **Scores and big numbers:** `UiKit.figure` (the DISPLAY face) is used in
  HubScene (1), MatchScene (2) and PlayerSheet (1). DISPLAY is used directly
  only in `match/PreMatchVignette.gd`. `UiKit.scoreline` formats `12.8 (80)`.
  Club-coloured score figures (STYLE-03) are coloured where `figure` is
  called, so a pairing rule belongs in a `UiKit` score helper.
- **Custom-drawn text** (`draw_string`) bypasses labels entirely:
  FormationView (3), PitchView (3), StoppageVignette (3), PreMatchVignette (2),
  MediaConferenceVignette, AwardWinnerVignette and BroadcastVignette (1 each).
  They use `UiKit.BOLD` or DISPLAY, **except three that use
  `ThemeDB.fallback_font` (not Barlow): PitchView, AwardWinnerVignette and
  BroadcastVignette.** That is a typography inconsistency in its own right;
  those files are the art agent's (M8-007), so it's flagged to them.

## The STYLE-01 Training-row alignment bug (`KNOWN BUG`): cause found

`TrainingScene._player_row`: the row is a 58-high button holding an
`hbox(8)` of a role chip, an `info` `vbox(1)` (the name in 15 bold, then the
plan line in 12), an optional status stamp (11), and the OVR label (17). The
`info` VBoxContainer fills the row's height (the default vertical fill) with
the default `ALIGNMENT_BEGIN`, so the name/plan stack sits at the top while the
chip and the OVR label sit in the middle. That's the off-centre stack the
director saw. **One-line fix:** `info.alignment = BoxContainer.ALIGNMENT_CENTER`,
which keeps names left-aligned and columns stable. This is LOW, independent
of the wider restyle, and needs dark 320/390 captures with one- and two-line
states.

## Suggested order once the art agent's treatment is approved

1. Add the approved type roles and a list-row builder to UiKit.
2. Move the eight files' local buttons and styleboxes onto `style_button`/
   the row builder.
3. Map literal sizes to roles, screen by screen: Training and Selection first
   (the dark slice), then the rest.
4. Add a score helper for club-colour pairings.
5. Swap `fallback_font` to Barlow in the three drawn-text files, with the art
   agent.
