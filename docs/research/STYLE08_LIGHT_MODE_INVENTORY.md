# STYLE-08 light-mode inventory (2026-10-06)

Inventory only, as the roadmap asks (§9.5 STYLE-08): no fix is made here, and no fix starts until the art agent and the director say so. Light mode is the secondary theme; dark stays the default.

**How it was measured.** The contrast of the actual light-theme pairs in `UiKit` (the same colours the screens use), by the WCAG ratio: 4.5 for normal text, 3.0 for large text and outlines. The capture is the shared component sheet in light mode ([style08_light_component_states.png](style08_light_component_states.png), 390 wide): buttons in each state, tabs, and club-coloured scores. Every ratio below comes from the game's colour constants, not from reading an image.

**What was not done.** A capture of every screen in light mode. Only the shared components were captured; the screens are built from them, so the defects below will reach the screens, but a screen-by-screen pass is still to do and is the next step.

## Defects, worst first

| # | Pairing | Ratio | Against | What it does |
|---|---|---|---|---|
| 1 | Club score ink on the page, in a club's accent colour (`MatchScene._score_column`) | 1.14 for ESS, GWS, HAW, MEL, RIC, STK, WCE, WBD (white accent); 1.27 ADE; 1.36 NTH; 1.45 BRL; 1.60 PAD; 1.61 COL; 1.63 CANB; 1.88 GEE; 2.17 CAR; 2.87 FRE | 3.0 for a 30 to 36 px figure | 17 of 20 clubs have a score that is hard or impossible to read on the light page. White-accent clubs vanish. Visible in the sheet: the Magpies grey and the Bombers white scores. Only SYD (15.28), TAS (5.00) and GCS (4.09) read well. |
| 2 | Primary button label: TEXT (dark ink) on the red ACCENT fill | 3.03 normal, 3.48 hover, 2.38 pressed | 4.5 | The one red primary button per screen is the weakest text on the page. Pure white on the same fill is 5.73. |
| 3 | Button and panel outlines | secondary outline 1.53 on the page, 1.38 on a panel; disabled outline 1.34; rule (LINE) 1.67 | 3.0 | Outline buttons and dividers are barely there. The selected state (TEXT outline, 15.22) is fine. |
| 4 | Disabled text: FAINT on the page | 2.70 | 4.5 | Disabled buttons nearly vanish (visible on the sheet's Disabled column). |
| 5 | MUTED on a panel | 4.34 on a panel, 3.84 on a panel inside a panel | 4.5 | Secondary labels dip under on every panelled surface. On the bare page MUTED is 4.83 and passes. |
| 6 | GOOD on a panel | 4.23 | 4.5 | Green state text on panels. On the page it is 4.71 and passes. |

Passing: TEXT on the page, a panel and a panel inside a panel (15.22, 13.68, 12.10); BAD on the page and a panel (5.13, 4.61); the secondary and selected button fills (13.00 and above); the selected outline (15.22).

## How the club-colour problem differs from dark

The same accent-colour scores are painted in dark mode too. The dark inventory is in [STYLE03_DARK_PAIRINGS_EVIDENCE.md](STYLE03_DARK_PAIRINGS_EVIDENCE.md); there the failures are different clubs (dark accents on a dark page). A score that reads in one theme fails in the other for many clubs, so a fix that follows the theme (choosing the club's accent or its primary, whichever reads on the page) would cover both.

## Next, if this goes ahead

1. The screen-by-screen light capture, with the existing capture tools (`tools/visual/capture_*.gd`, `CAP_MODE=light` on the component sheet; the others need a career set up).
2. The art agent's call on the primary button ink (white on the red, or a different accent in light), the outline colour and the score ink rule. These are appearance decisions and go through the director.
