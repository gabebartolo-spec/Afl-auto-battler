# Screen sweep, 2026-10-18

P-77 "One sweep of every screen" (director yes 2026-10-18). Every screen in `Router.SCENES`, opened on one seeded Melbourne career (seed 2031), dark theme, at the Android phone reference and the wide desktop. Made by `tools/visual/sweep_screens.gd` and `tools/screen_sweep.py`; the check against the committed baseline (`tools/visual/screen_sweep_baseline.json`) runs in the UI review sheets workflow.

- phone: window 390x844, 390x844 UI units, 1.0 px per unit.
- pc: window 1920x1080, 1280x720 UI units, 1.5 px per unit.

Figures: the smallest font on the screen in rendered px; controls whose rect leaves the viewport (sideways always, up or down only outside a scroll area); labels and buttons whose text is cut or ellipsised; buttons and tappable rows under 44 px in either direction. Examples are the first few found, not all.

## Result

This run is the baseline: the first run. Every figure above is now the floor.

## The table

| Screen | Size | Smallest font (px) | Off screen | Clipped | Targets under 44 px |
|---|---|---|---|---|---|
| coaching | phone | 12.0 | 0 | 0 | 0 |
| coaching | pc | 18.0 | 0 | 0 | 0 |
| draft | phone | 12.0 | 0 | 0 | 1 |
| draft | pc | 18.0 | 0 | 0 | 0 |
| forge | phone | 15.0 | 0 | 0 | 0 |
| forge | pc | 22.5 | 0 | 0 | 0 |
| hub | phone | 12.0 | 0 | 0 | 0 |
| hub | pc | 18.0 | 0 | 0 | 0 |
| list | phone | 11.0 | 108 | 0 | 0 |
| list | pc | 16.5 | 0 | 0 | 0 |
| main | phone | 13.0 | 0 | 0 | 0 |
| main | pc | 19.5 | 0 | 0 | 0 |
| match | phone | 13.0 | 0 | 0 | 7 |
| match | pc | 19.5 | 0 | 0 | 0 |
| offseason | phone | 12.0 | 0 | 0 | 0 |
| offseason | pc | 18.0 | 0 | 0 | 0 |
| preseason | phone | 13.0 | 0 | 0 | 0 |
| preseason | pc | 19.5 | 0 | 0 | 0 |
| season_review | phone | 12.0 | 0 | 0 | 0 |
| season_review | pc | 18.0 | 0 | 0 | 0 |
| selection | phone | 11.0 | 0 | 0 | 0 |
| selection | pc | 16.5 | 0 | 0 | 0 |
| staff | phone | 13.0 | 0 | 0 | 0 |
| staff | pc | 19.5 | 0 | 0 | 0 |
| stats | phone | 12.0 | 0 | 0 | 27 |
| stats | pc | 18.0 | 0 | 0 | 1 |
| training | phone | 12.0 | 0 | 0 | 0 |
| training | pc | 18.0 | 0 | 0 | 0 |

## Worst five findings

The five screen and size pairs with the most findings (off screen + clipped + small targets), with the first example of each.

- **list at phone**, 108 findings. off screen: Best22Board/BuilderField/Pitch Pitch "" spans x 24..366 y 405..1005 of 390x844
- **stats at phone**, 27 findings. small target: LadderTable/LadderHeader/Sort_pos Sort_pos "#" is 24x40 px
- **match at phone**, 7 findings. small target: @VBoxContainer@2156/@VBoxContainer@2170/MomentumBar MomentumBar "" is 354x30 px
- **draft at phone**, 1 findings. small target: @VBoxContainer@265/PositionFilters/Filter_ALL Filter_ALL "All" is 40x58 px
- **stats at pc**, 1 findings. small target: LadderTable/LadderHeader/Sort_pos Sort_pos "#" is 42x60 px

## Smallest font by screen

Where the smallest text sits, smallest first (both sizes).

- 11.0 px, list at phone: Spot_RUCK/@VBoxContainer@1697/@Label@1699 @Label@1699 "RUCK/MID 89"
- 11.0 px, selection at phone: Spot_RUCK/@VBoxContainer@1269/@Label@1271 @Label@1271 "RUCK/MID 89"
- 12.0 px, coaching at phone: ClubPlan_balanced/@VBoxContainer@1863/Strength Strength "Plays it straight"
- 12.0 px, draft at phone: Position_DEF/@VBoxContainer@200/Need_DEF Need_DEF "short 6"
- 12.0 px, hub at phone: WeekEvent/@VBoxContainer@1115/@Label@1119 @Label@1119 "He's out of contract at
- 12.0 px, offseason at phone: @PanelContainer@2615/@VBoxContainer@2616/@Label@2618 @Label@2618 "Leave one of your best 
- 12.0 px, season_review at phone: @VBoxContainer@2351/@HBoxContainer@2357/@Label@2358 @Label@2358 "Points for"
- 12.0 px, stats at phone: LadderTable/LadderHeader/Sort_pos Sort_pos "#"

## Examples

- draft at phone
  - targets under 44 px: @VBoxContainer@265/PositionFilters/Filter_ALL Filter_ALL "All" is 40x58 px
- list at phone
  - off screen: Best22Board/BuilderField/Pitch Pitch "" spans x 24..366 y 405..1005 of 390x844
  - off screen: BuilderField/Pitch/Spot_FF Spot_FF "" spans x 160..230 y 916..960 of 390x844
  - off screen: Spot_FF/@VBoxContainer@1733/@Label@1734 @Label@1734 "van Rooyen" spans x 166..224 y 925..938 of 390x844
- match at phone
  - targets under 44 px: @VBoxContainer@2156/@VBoxContainer@2170/MomentumBar MomentumBar "" is 354x30 px
  - targets under 44 px: @VBoxContainer@2187/@HBoxContainer@2179/@Button@2180 @Button@2180 "Play" is 66x40 px
  - targets under 44 px: @VBoxContainer@2187/@HBoxContainer@2179/@Button@2181 @Button@2181 "1x" is 66x40 px
- stats at phone
  - targets under 44 px: LadderTable/LadderHeader/Sort_pos Sort_pos "#" is 24x40 px
  - targets under 44 px: LadderTable/LadderHeader/Sort_club Sort_club "Club" is 66x40 px
  - targets under 44 px: LadderTable/LadderHeader/Sort_p Sort_p "P" is 26x40 px
- stats at pc
  - targets under 44 px: LadderTable/LadderHeader/Sort_pos Sort_pos "#" is 42x60 px

## Not exercised

- One state per screen: the first view, not every tab, sheet, popup or scrolled position. A screen with several states (the hub across a season, the match through its quarters) is measured once.
- Text sizes other than the default: P-04's text-size setting does not exist yet, so the sweep runs at one.
- A tap is not made: a target is judged by the size of its rect, not by whether another control covers it.
- Wrapped text that is simply too long for a screen is not a finding unless it is cut; only a person looking at the sheets sees that.
- The light theme (parked by the director, 2026-10-13) and the club colour choice: one club, dark only.
- Real devices: sizes are the window's pixels on a software renderer; a phone's own scaling is not applied.
