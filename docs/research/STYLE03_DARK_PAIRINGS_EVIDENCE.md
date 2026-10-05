# STYLE-03 evidence: dark-mode text, action and club-colour pairings

Prepared by the low agent for the art agent (roadmap §9.5 STYLE-03, prep only). **Measurements only: no colour has been changed and nothing here recommends a treatment.** The art agent proposes; the director chooses.

## Method and limits
- Ink and fill colours are read from the running game: the dark palette in `UiKit.gd` (`BG`, `PANEL`, `PANEL_ALT`, `TEXT`, `MUTED`, `FAINT`, `GOOD`, `BAD`, `ACCENT`, `LINE`), the button states built by `UiKit.style_button` / `set_selected` (hover and pressed fills are blended over the surface), and each club's colours from `data/clubs.csv` via `GameDB.club_colours`.
- The contrast ratio is the WCAG 2.x relative-luminance ratio. Thresholds used: 4.5 for ordinary text, 3.0 for large text (the 30-36 px scores) and for outlines. It is supporting evidence about the pairs below, not a certificate for the whole game, and it is not an Android review.
- The live score is painted in the club's **third colour** (`MatchScene._score_column`, `cols[2]`) with no legibility adjustment. That is why a club's score ink depends on a colour chosen for a pitch tint.
- Not yet covered: light mode, render sheets of each component state at 320/390 widths, and the match-header surfaces other than the page and panel fills. Those are the next pieces if the art agent wants them.

## Headlines
1. **SYD's score is effectively invisible.** Its third colour is `#1a1a1a`: 1.08:1 on the page and 1.00:1 on a panel. Every Sydney fixture shows one readable score and one that is not (SYD v ESS, RIC, STK, WCE, WBD, GWS are the widest gaps, 17.8).
2. **Two more club scores are weak:** TAS 3.32 (3.06 on a panel) and GCS 4.05 on the page. Both are under 4.5; TAS is barely over the 3.0 large-text line.
3. **The COL v ESS case:** COL's score ink is `#bfbfbf` (10.26) and ESS's is `#ffffff` (18.86). Both are very legible in absolute terms; the gap is 8.6, so the Essendon score is the brighter figure on the screen. COL's primary is `#141414`, so the club colour that reads as "Collingwood" is the guernsey, not the score ink.
4. **Primary button ink is under 4.5.** The cream `TEXT` on the red `ACCENT` fill is 4.26 normal and 3.78 on hover; pressed (a darker fill) is 5.51. For comparison, pure white on the same red is 4.94 and near-black ink is 3.95.
5. **Inactive secondary labels read as quieter, not disabled.** `MUTED` is 7.07 on the page against `TEXT` 16.27 (2.3 times lower). The disabled colour `FAINT` is 3.46, under 4.5.
6. **Outlines are faint.** The secondary-button outline is 2.16 on the page and 1.99 on a panel, the disabled outline 1.23 and a rule 1.48, all under 3.0. The selected outline (`TEXT`) is 16.27, so selection is clear; the unselected outline is what is faint.

## Text on the dark surfaces (WCAG contrast; 4.5 normal text, 3.0 large text and UI outlines)
| pair | ink | surface | ratio | against 4.5 |
|---|---|---|---|---|
| TEXT on page | #f1eee6 | #121110 | 16.27 | ok |
| TEXT on panel | #f1eee6 | #1b1a17 | 15.01 | ok |
| TEXT on panel on panel | #f1eee6 | #24221e | 13.69 | ok |
| MUTED on page | #a39e93 | #121110 | 7.07 | ok |
| MUTED on panel | #a39e93 | #1b1a17 | 6.52 | ok |
| MUTED on panel on panel | #a39e93 | #24221e | 5.95 | ok |
| FAINT (disabled) on page | #6e695f | #121110 | 3.46 | **below 4.5** |
| GOOD on page | #8cc49a | #121110 | 9.41 | ok |
| GOOD on panel | #8cc49a | #1b1a17 | 8.68 | ok |
| BAD on page | #e38b73 | #121110 | 7.37 | ok |
| BAD on panel | #e38b73 | #1b1a17 | 6.80 | ok |

## Buttons: label ink on the actual fill, per state
| pair | ink | fill | ratio | against 4.5 |
|---|---|---|---|---|
| Primary, normal: TEXT on ACCENT | #f1eee6 | #c8412b | 4.26 | **below 4.5** |
| Primary, hover: TEXT on ACCENT lightened 8% | #f1eee6 | #cc503c | 3.78 | **below 4.5** |
| Primary, pressed: TEXT on ACCENT darkened 15% | #f1eee6 | #aa3725 | 5.51 | ok |
| (compare) near-black ink 0d0c0b on ACCENT | #0d0c0b | #c8412b | 3.95 | **below 4.5** |
| (compare) pure white on ACCENT | #ffffff | #c8412b | 4.94 | ok |
| Secondary, normal: TEXT on page | #f1eee6 | #121110 | 16.27 | ok |
| Secondary, hover (TEXT 5%): TEXT | #f1eee6 | #1d1c1b | 14.67 | ok |
| Secondary, pressed (TEXT 8%): TEXT | #f1eee6 | #242321 | 13.59 | ok |
| Selected choice: TEXT on selected fill (page) | #f1eee6 | #242321 | 13.59 | ok |
| Selected choice: TEXT on selected fill (panel) | #f1eee6 | #2c2b28 | 12.22 | ok |
| Unselected choice of a set: MUTED on page | #a39e93 | #121110 | 7.07 | ok |
| Unselected choice of a set: MUTED on panel | #a39e93 | #1b1a17 | 6.52 | ok |
| Danger: BAD on page | #e38b73 | #121110 | 7.37 | ok |
| Disabled: FAINT on page | #6e695f | #121110 | 3.46 | **below 4.5** |

Active versus inactive label: TEXT 16.27 against MUTED 7.07 on the page, so an inactive secondary label (MUTED) is 2.30 times lower in contrast than an active one; both pass 4.5 on the page.

## Outlines (non-text, 3.0)
| outline | colour | against | ratio | against 3.0 |
|---|---|---|---|---|
| Secondary button outline (LINE lightened 12%) on page | #4e4b43 | #121110 | 2.16 | **below 3.0** |
| Secondary button outline on panel | #4e4b43 | #1b1a17 | 1.99 | **below 3.0** |
| Disabled outline (LINE at 60%) on page | #28251f | #121110 | 1.23 | **below 3.0** |
| Selected outline (TEXT) on page | #f1eee6 | #121110 | 16.27 | ok |
| Rule (LINE) on page | #363229 | #121110 | 1.48 | **below 3.0** |

## Club-coloured score figures (the score is painted in each club's accent colour, index 2, on the page)
| club | primary | secondary | accent (score ink) | score on page | score on panel |
|---|---|---|---|---|---|
| ADE | #002b5c | #e21937 | #ffd200 | 13.00 | 11.99 |
| BRL | #a30046 | #0055a3 | #fdbe57 | 11.39 | 10.51 |
| CAR | #0b1f4b | #ffffff | #7fa7e0 | 7.64 | 7.05 |
| COL | #141414 | #ffffff | #bfbfbf | 10.26 | 9.46 |
| ESS | #1a1a1a | #cc2031 | #ffffff | 18.86 | 17.40 |
| FRE | #2a0d54 | #ffffff | #a67fc1 | 5.77 | 5.33 |
| GEE | #002b5c | #ffffff | #8fb4e3 | 8.81 | 8.13 |
| GCS | #e02112 | #ffdd00 | #0079c1 | 4.05 | 3.73 |
| GWS | #f47920 | #3c3c3b | #ffffff | 18.86 | 17.40 |
| HAW | #4d2004 | #fbbf15 | #ffffff | 18.86 | 17.40 |
| MEL | #0a1f44 | #cc2031 | #ffffff | 18.86 | 17.40 |
| NTH | #1a3b8e | #ffffff | #c4d1e5 | 12.21 | 11.27 |
| PAD | #008aab | #1a1a1a | #c0c0c0 | 10.37 | 9.56 |
| RIC | #ffd200 | #1a1a1a | #ffffff | 18.86 | 17.40 |
| STK | #ed1b2f | #1a1a1a | #ffffff | 18.86 | 17.40 |
| SYD | #e1251b | #ffffff | #1a1a1a | 1.08 | 1.00 |
| WCE | #003087 | #f2a900 | #ffffff | 18.86 | 17.40 |
| WBD | #bd002b | #20539d | #ffffff | 18.86 | 17.40 |
| TAS | #2c5530 | #e8d44d | #c2274d | 3.32 | 3.06 |
| CANB | #1b3b6f | #ffffff | #f5b301 | 10.18 | 9.39 |

Clubs whose score ink is below 3.0 on the page (large-text threshold; the score is 30-36 px): SYD 1.08.
Below 4.5: GCS 4.05, SYD 1.08, TAS 3.32.

Widest legibility gaps between the two scores of one fixture (all 190 pairings):
| fixture | left | right | gap |
|---|---|---|---|
| ESS v SYD | 18.86 | 1.08 | 17.78 |
| RIC v SYD | 18.86 | 1.08 | 17.78 |
| STK v SYD | 18.86 | 1.08 | 17.78 |
| SYD v WCE | 1.08 | 18.86 | 17.78 |
| SYD v WBD | 1.08 | 18.86 | 17.78 |
| GWS v SYD | 18.86 | 1.08 | 17.78 |
| **COL v ESS (the audited case)** | 10.26 | 18.86 | 8.60 |
