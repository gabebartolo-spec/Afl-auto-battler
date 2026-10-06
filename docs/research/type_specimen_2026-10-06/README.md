# Type specimen: current, Barlow set better, Source Sans 3 (2026-10-06)

The director's brief: the Codex research "Claude_Bespoke_UI_and_Font_Research",
assessed against the current UI, active branches, the existing style research
and STYLE-01/02/05. This is **evidence for the art agent and the director,
not a rollout**. No game file changes, no font is added to the game, and
nothing goes on the roadmap. The art agent leads the treatment; the director
chooses.

## What was compared

The same real content, set three ways side by side. Colours, selection
styles and control shapes are held constant, so only the type differs.

| column | fonts | what changes |
|---|---|---|
| **Current** | Barlow Regular / SemiBold, Barlow Condensed Bold for scores | nothing: each component as its screen sets it today (TrainingScene, ListScene, MatchScene, HubScene, UiKit) |
| **A: Barlow, set** | the same three files | one type scale, tabular figures, a plain guernsey numeral, a left-anchored header, an editorial hierarchy for the report |
| **B: Source Sans 3 + Serif 4** | Source Sans 3 Regular / Semibold / Bold; Source Serif 4 Semibold for the report headline only | A's roles exactly, size-matched to Barlow's x-height (x 1.041); the serif headline set a tenth smaller than A's (the art agent's note) |

**Components:**
- Hub header: the top bar, ground, opponent and form line.
- Training rows: normal, selected, the league's longest name, injured.
- Full list rows: guernsey number, long name, out injured.
- The match scoreboard.
- Controls: primary, selected, unselected and disabled.
- A short editorial report.
- A look-alike line: `Il1 O0 689 12.8 (80) 9.17 (71) $850k $1.25m`.

**Content:**
- Melbourne's real list (Max Gawn, Jacob van Rooyen, Jake Lever), the league's longest name (Nasiah Wanganeen-Milera) and Collingwood's Nick Daicos.
- Real plan and development lines from GameState, and the real lead line from MatchNotes.
- AFL score notation, 12.8 (80) against 9.17 (71).
- The report text is specimen copy and is labelled as such.

**Captures:**
| file | what it is |
|---|---|
| `t390.png` | phone portrait, 390 logical, at 1x |
| `t320.png` | the narrowest phone, 320 logical, at 1x |
| `t390_2x.png` | 390 at 2x pixel density, as a phone rasterises it |
| `t390_text130.png`, `t320_text130.png` | every text size × 1.3 with the layout unchanged: the larger-text check |
| `desk640.png` | desktop: the wide variants of each component (full club names, 36-pt scores) in 640-wide columns |

The fullscreen version (2x, STYLE-07's density on a 2560 screen) was
captured too. It isn't committed because of its size: 4032 px wide.
Regenerate it with the tool. The tool draws offscreen in a SubViewport, so
a 2x sheet really is 2x: the window would be clamped to the display. For any
windowed Godot run, use an untracked `override.cfg` with
`window/size/no_focus=true` and an offscreen position, so a capture never
takes the director's focus.

**Tool:**
```
godot --path . --rendering-driver opengl3 --script tools/visual/capture_type_specimen.gd \
    -- --out /tmp/type_390 --col 390 [--scale 2] [--text 1.3] [--fonts DIR]
```
- `--fonts` is a folder holding the Source Sans 3 and Source Serif 4 TTFs. Without it, the tool draws only Current and A.
- The tool also prints each font's measurements and the contrast of the specimen's colour pairs.

## Measurements (printed by the tool)

| | x-height at 100 px | cap height | '1' / '8' advance, as shipped | '1' / '8' with tabular figures on |
|---|---|---|---|---|
| Barlow Regular | 51 | 70 | **35 / 52 (proportional)** | 53 / 53: `tnum` works through `FontVariation.opentype_features` |
| Source Sans 3 Regular | 49 | 66 | 50 / 50 (tabular by default) | 50 / 50 |

- **Barlow ships proportional figures.** Today a rating column of 89 / 74 / 75 doesn't line up, and a score changing from 11.8 to 18.8 changes width. The game never switches `tnum` on.
- **Godot honours Barlow's `tnum`.** The art agent asked for this to be checked before the comparison could count as fair.

**Contrast (WCAG, on the actual dark surfaces; supporting evidence only):**
| pair | ratio | note |
|---|---|---|
| TEXT on BG | 16.27 | |
| MUTED on BG | 7.07 | |
| MUTED on PANEL | 6.52 | |
| FAINT (disabled) on BG | 3.46 | disabled text is exempt from the 4.5 target |
| BAD on BG | 7.37 | |
| GOOD on BG | 9.41 | |
| TEXT on ACCENT | 4.26 | the primary button: 16-pt semibold is just under 4.5 |
| role colours on BG | 8.8–10.6 | |
| **club score colours on the scoreboard PANEL** | **SYD 1.00**, TAS 3.06, GCS 3.73 | Sydney's accent (#1A1A1A) is the panel's colour (#1B1A17), so **Sydney's live score is invisible**. A correctness defect; handed to low as a narrow fix (backlog Low 20). |

## Findings

1. **A fits everywhere Current fits.** At 320 and at 130% text, every line truncates in the same places as today.
   - The changes are small, and they are mostly consistency.
   - The training row's sizes now match the Full list's:
     - name 15 → 16;
     - secondary 12 → 13;
     - rating 17 → 20.
   - The STYLE inventory counts 16 literal sizes across about 245 calls, and A's single scale is that inventory's main recommendation.
2. **Tabular figures are the clearest win, and they cost nothing.**
   - Ratings line up in a column.
   - Scores no longer change width as they tick over.
   - "Q4 27'" holds still.
3. **The plain guernsey numeral (A, B; Barlow Condensed 18, near the name's cap height, so the name stays the first read) reads as a shirt number rather than a badge.**
   - It frees the club colours from a small chip, where navy-on-navy borders were barely visible.
   - Trade-off: the club's colour leaves the row. The art agent's number-mark motif (STYLE-05) is the place to bring identity back.
4. **The left-anchored header with a neutral band** fixes the off-centre title. The title was centred in the space left by the right-hand Settings button, not on the screen. The band is a placeholder for the art agent's motif, and deliberately plain.
5. **B fails the narrow phone.**
   - Source Sans 3 has no condensed width, so the scoreboard's `12.8 (80) … 9.17 (71)` needs more than 320 logical units. The whole column overflows at 320, and badly at 130% text.
   - B also wraps one more line in the training row's secondary text and in the headline.
   - To survive, B would need Barlow Condensed kept for scores. At that point it is a two-family system for little gain over A.
6. **Source Serif 4 for the report headline** gives the report a publication voice that Barlow SemiBold doesn't.
   - It separates a story from a task screen.
   - It costs one line at 390, and it is the one place a second family earns its keep.
   - It has to stay limited to editorial headlines (news, season review, FL-006 headlines). Never controls or rows.

## The art agent's read (they lead the visual treatment)

- **Verdict: A.** B breaks the 320 scoreboard and costs a line everywhere.
- **The guernsey numeral:** take it down to about the name's cap height, so the name stays the first read. Done in these captures: 18, down from 20.
- **The header:** the left-anchored Hub header with the rule under it is a clear improvement; keep it.
- **The serif headline:** offer it as a choice, not a default. If it stays:
  - about 10% smaller than A's headline (done: 23);
  - a balanced wrap, with no single-word last line. Godot's Label can't do this natively; it would need a small UiKit helper;
  - only on reports. Next to Barlow it can read like a second publication.
- **Primary-button text** (TEXT on ACCENT, 4.26): lift the text or darken the accent a step. That's a colour choice for STYLE-03.

## Recommendation

- **Take A as the direction: the Barlow the game already has, set deliberately.**
  - Keep the three existing files.
  - Turn on tabular figures through FontVariation in UiKit.
  - Map the roles (screen title, section, name, secondary, rating, number mark, score, body, fine print) to UiKit constants.
  - Retire the literal sizes screen by screen, as screens are touched.
- **Treat the serif headline as an option for the director.** It means adding Source Serif 4 Semibold, about 270 KB under the OFL, for editorial headlines only.
- **Don't adopt Source Sans 3.** It is well made and readable, but:
  - it adds nothing Barlow lacks once Barlow is set properly;
  - it loses the condensed score face;
  - it breaks the 320 layout.
- **Atkinson Hyperlegible Next was not tried.** On the art agent's advice it is held back unless the larger-text captures showed B failing for legibility. B failed for width, not legibility.
- **A custom font is not justified.** Identity is better spent on the number mark, the header motif and score composition, which are the art agent's STYLE-05 work.

**Not done here; needed before anything ships:**
- the art agent's treatment;
- the director's choice;
- real Android rasterisation at ordinary viewing distance;
- draft rows;
- light mode (STYLE-08 follows dark).

## Licences

| font | source | licence |
|---|---|---|
| Barlow, Barlow Condensed | already in `assets/fonts/` | SIL OFL 1.1; `Barlow-OFL.txt`, `BarlowCondensed-OFL.txt` |
| Source Sans 3 (3.052R) | github.com/adobe-fonts/source-sans, `release` branch, `TTF/` | SIL OFL 1.1, Reserved Font Name "Source" |
| Source Serif 4 (4.005R) | github.com/adobe-fonts/source-serif, `release` branch, `TTF/` | SIL OFL 1.1, Reserved Font Name "Source" |

- The Source fonts were used for this comparison only and are not in the repository.
- Bundling one would need its licence file beside it. A modified version could not be called "Source".
