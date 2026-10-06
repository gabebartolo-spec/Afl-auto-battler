# STYLE-08 light-mode inventory (2026-10-06)

Inventory only, as the roadmap asks (§9.5 STYLE-08): no fix is made here, and no fix starts until the art agent and the director say so. Light mode is the secondary theme; dark stays the default.

**How it was measured.** The contrast of the actual light-theme pairs in `UiKit` (the same colours the screens use), by the WCAG ratio: 4.5 for normal text, 3.0 for large text and outlines. The capture is the shared component sheet in light mode ([style08_light_component_states.png](style08_light_component_states.png), 390 wide): buttons in each state, tabs, and club-coloured scores. Every ratio below comes from the game's colour constants, not from reading an image.

**Screens captured (part 2).** The ladder, team selection, training and my-list screens of a fresh Melbourne career, at 390 wide, with `tools/visual/capture_screens_light.gd` (new: `CAP_MODE=light` or `dark`). Also the offseason and the League Draft. The match and Club Forge screens are in part 3 below.

## Defects, worst first (seven)

| # | Pairing | Ratio | Against | What it does |
|---|---|---|---|---|
| 1 | Club score ink on the page, in a club's accent colour (`MatchScene._score_column`) | 1.14 for ESS, GWS, HAW, MEL, RIC, STK, WCE, WBD (white accent); 1.27 ADE; 1.36 NTH; 1.45 BRL; 1.60 PAD; 1.61 COL; 1.63 CANB; 1.88 GEE; 2.17 CAR; 2.87 FRE | 3.0 for a 30 to 36 px figure | 17 of 20 clubs have a score that is hard or impossible to read on the light page. White-accent clubs vanish. Visible in the sheet: the Magpies grey and the Bombers white scores. Only SYD (15.28), TAS (5.00) and GCS (4.09) read well. |
| 2 | Primary button label: TEXT (dark ink) on the red ACCENT fill | 3.03 normal, 3.48 hover, 2.38 pressed | 4.5 | The one red primary button per screen is the weakest text on the page. Pure white on the same fill is 5.73. |
| 3 | Button and panel outlines | secondary outline 1.53 on the page, 1.38 on a panel; disabled outline 1.34; rule (LINE) 1.67 | 3.0 | Outline buttons and dividers are barely there. The selected state (TEXT outline, 15.22) is fine. |
| 4 | Disabled text: FAINT on the page | 2.70 | 4.5 | Disabled buttons nearly vanish (visible on the sheet's Disabled column). |
| 5 | MUTED on a panel | 4.34 on a panel, 3.84 on a panel inside a panel | 4.5 | Secondary labels dip under on every panelled surface. On the bare page MUTED is 4.83 and passes. |
| 6 | GOOD on a panel | 4.23 | 4.5 | Green state text on panels. On the page it is 4.71 and passes. |
| 7 | Position tags (`UiKit.ROLE_COLOUR`, one fixed colour per line in both themes) | DEF 1.69; MID 1.51; RUCK 1.40; FWD 1.61 on a panel | 4.5 | The tags on every list, draft and offseason screen are the palest text on the page. They were chosen for the dark theme and are not adapted for light. On the page: DEF 1.88; MID 1.68; RUCK 1.56; FWD 1.79. |

Passing: TEXT on the page, a panel and a panel inside a panel (15.22, 13.68, 12.10); BAD on the page and a panel (5.13, 4.61); the secondary and selected button fills (13.00 and above); the selected outline (15.22).

## How the club-colour problem differs from dark

The same accent-colour scores are painted in dark mode too. The dark inventory is in [STYLE03_DARK_PAIRINGS_EVIDENCE.md](STYLE03_DARK_PAIRINGS_EVIDENCE.md); there the failures are different clubs (dark accents on a dark page). A score that reads in one theme fails in the other for many clubs, so a fix that follows the theme (choosing the club's accent or its primary, whichever reads on the page) would cover both.

## Next, if this goes ahead

1. The screen-by-screen light capture, with the existing capture tools (`tools/visual/capture_*.gd`, `CAP_MODE=light` on the component sheet; the others need a career set up).
2. The art agent's call on the primary button ink (white on the red, or a different accent in light), the outline colour and the score ink rule. These are appearance decisions and go through the director.

## What the screens show (part 2)

Seen in [ladder](style08_light_screen_ladder.png), [selection](style08_light_screen_selection.png), [training](style08_light_screen_training.png), [my list](style08_light_screen_list.png), [offseason](style08_light_screen_offseason.png) and [League Draft](style08_light_screen_draft.png):

| Screen | Defect | Pairing behind it |
|---|---|---|
| Training, list rows | The role tags ("RUCK/MID" in gold, "MID" in green) are pale on the panel and hard to read. | Position tags on a panel (defect 7). |
| Training, role tabs | "DEFS", "MIDS", "RUCKS", "FWDS" and the row sub-lines ("Position plan · Developing") are faint. | MUTED on a panel (4.34, defect 5). |
| Team selection | "Your side has: Lockdown unit..." in green on the panel, and the unselected "Dual ruck" and "My selection" look disabled. | GOOD on a panel (4.23, defect 6) and MUTED on a panel (defect 5). |
| My list, the oval | Player names and position codes on the grass are dark text on dark green; the Interchange strip is a dark translucent panel with dark labels. This is the "grass label" case the roadmap names. | Fixed-colour football art inheriting the theme text colour, which is exactly what STYLE-08 says to avoid by giving the art its own foreground and background. |
| Ladder | Reads well. The column headers ("Club", "W-L", "Pts") and zero records are the MUTED-on-panel dip only. | Defect 5. |
| League Draft | The position tags (MID green, DEF blue, FWD salmon, RUCK gold) and the line chips ("DEF 0 short 6", "RUCK 0 need 2") are pale on the panel; "Start season" (disabled) nearly vanishes. | Position tags on a panel (defect 7); FAINT on the page (defect 4). |
| Offseason | The green payroll summary and the pale role tags on the contract cards; secondary lines ("60 OVR · age 34 · 0 games this year") dip. | GOOD on a panel (defect 6), position tags on a panel (defect 7), MUTED on a panel (defect 5). |
| Intro sheet (hub) | The red "Got it" button has dark ink on red. | Defect 2 (3.03). |

## What the screens show (part 3)

The live match (`tools/visual/capture_match_light.gd`) and the Club Forge screens (`tools/visual/capture_forge_light.gd`), at 390 wide, `CAP_MODE=light`. The Forge screens are not on main yet: they were captured on the #360 branch, so the capture needs that branch (or main once #360 lands).

Seen in the match [before the first bounce](style08_light_screen_match_light_prebounce.png) and [in play](style08_light_screen_match_light_play.png), and the Club Forge [home](style08_light_screen_forge_light_home.png), [Create a player](style08_light_screen_forge_light_player.png) and [Create a club](style08_light_screen_forge_light_club.png):

| Screen | Defect | Pairing behind it |
|---|---|---|
| Match, the scoreboard | **New, defect 8.** The home side's score is white on the light panel (about 1.3 to 1), so it nearly disappears. The other side's dimmed score is faint too. The club name and the bar under them read fine. | A fixed white ink on a theme panel; the dark theme's panel is dark, so it never showed there. Worth measuring as a rule: any fixed-colour text drawn on a panel. |
| Match, the pitch | The oval and the dark surround stay dark in light mode. This is the football art, not a defect, but it makes a very hard edge against the cream panels. | A design call for the art agent. |
| Match, the pre-bounce box | Reads well. The unselected gameplan and tag buttons and the grey help lines are the MUTED-on-panel dip. | Defect 5. |
| Match, "Bounce the ball" | The red primary button has dark ink on red. | Defect 2 (3.03). |
| Club Forge, home | "Create a player" is the red button with dark ink. The grey explainer text is MUTED on the page and reads, just. | Defect 2 (3.03), defect 5. |
| Club Forge, forms | The unselected state, place and design buttons look disabled next to the one selected (a dark outline on the cream). The input placeholders ("Club name", "Nickname...") are faint. | MUTED on a panel (defect 5); FAINT (defect 4). |

Still to do from here: the art agent's call on the fixes, and the director's look at any appearance change. The position-colour numbers are in defect 7.

