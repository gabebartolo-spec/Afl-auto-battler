# 9.5 Approved visual styling work — director interview, 2026-10-06

**Engineering inventory (2026-10-06):** [dark-slice component inventory](STYLE_COMPONENT_INVENTORY_2026-10-06.md) lists where buttons, rows, type sizes and score styles are built or overridden outside `UiKit`, and the landing order once the art agent's treatment is approved.

**Decision record:** the director answered **Include** to STYLE-01 through STYLE-08, in order, after asking for a one-at-a-time interview. All eight are accepted; there were **no rejections** to retain in a candidate queue. The director separately confirmed the off-centre **player-row text** in the dark Training capture as a defect. This is not a complaint about the Training heading.

**Status boundary:** inclusion authorises the scoped work below, not its final appearance or a claim of implementation. Initial status is `TODO`, with a `KNOWN BUG` alignment subtask. Inspect current code, the art agent's work and open PRs before changing a captured problem; the research snapshot predates later commits. Existing DONE foundations remain DONE. Reuse these IDs when recording progress rather than opening parallel styling systems.

**Authority:** the art agent has higher authority than ChatGPT on visual direction. Claude implements the art agent's treatment and reports engineering constraints rather than substituting its own taste. **All final decisions go through the director.** Accepted scope permits concrete mockups, prototypes and reviewable implementation; final font, palette, geometry, positioning and scene treatment require the director's approval. Do not merge an unapproved final visual treatment merely because ordinary CI passes. This is an explicit task-specific visual gate, not a request to re-interview the accepted scope.

**Priority:** **STYLE-07's unreadable PC fullscreen repair is an immediate P0 override** under §0.4.1. Beyond that repair, Android portrait dark mode leads the broader styling programme; remaining desktop polish and STYLE-08 light mode follow the approved dark slice. Preserve urgent P0 correctness, phone and performance gates. Coordinate hot files (`UiKit.gd`, shared layout, MatchScene and vignette overlays) with the existing art work; no competing redesign branch.

**Research:** [dark-mode audit](research/AFL_UI_STYLE_AUDIT_AND_RESEARCH.md) and [player-led source ledger](research/AFL_UI_STYLE_SOURCE_LEDGER.md). Competitor screenshots/claims are evidence and options, not approved templates. AFCM and Footy Redraft remain negative aesthetic references. The Windows render audit is preliminary evidence, not a completed native Android playtest or Claude engineering audit.

## STYLE-01 — Bespoke dark-mode controls and Training-row alignment
**Status:** `TODO` · **Priority:** `P1` · **Autonomy:** `SUPERVISED`  
**Existing owner:** §1.7 anti-slop reset/shared UiKit, Training and Selection; presentation follow-up under M8-006. Do not reopen M8-002's completed neutral-colour foundation.

**Goal/scope:** have the art agent design Training and Selection row/button treatments with less repetitive outlined-box styling and a recognisably football-specific identity. Preserve the same information, selection semantics and comfortable touch areas; typography, rules and purposeful silhouettes may replace visual enclosures.

**Alignment subtask — `DONE` in #277 (reconciled 2026-10-07):** Training name/plan stacks were centred against role/rating, with regression coverage. Only reopen on a current-build reproduction. **Original observed defect:** in the audited dark Training rows the name/secondary-line stack sits too high while the role/rating sit nearer the row middle. Inspect `TrainingScene._player_row` against the current build; repair the stack's vertical alignment while retaining left-aligned names and stable columns. Do not centre every line horizontally or mistake this for a heading complaint. This repair is not conditional on adopting a broader row restyle.

**Dependencies:** art-agent ownership/current-branch reconciliation; coordinate type/colour decisions with STYLE-02/03. A narrow alignment repair may proceed independently.

**Exclusions:** changing training, selection, ratings, data quantity or information architecture; new UI frameworks or extra icons/cards merely for decoration.

**Acceptance:** approved row/action grammar is consistent across the chosen slice; names/secondary stacks are vertically balanced against roles/ratings; normal, selected, pressed and disabled states are distinct without becoming card piles; no lost content or reduced hit area.

**Validation:** dark 320/390 captures, native narrow/common Android portrait, long/short names, one/two/extra-line states, injury/reserve/status labels, bulk selection and scroll-versus-tap behaviour. Use relevant Training/selection/UI checks for changed behaviour, not tests that only assert a preferred hex value. Director reviews final appearance.

## STYLE-02 — Dark-mode typography and numeral refinement
**Status:** `TODO` · **Priority:** `P1` · **Autonomy:** `SUPERVISED`  
**Existing owner:** §1.7 typography/free-font remit, shared UiKit; M8-006 presentation.

**Preparation merged (2026-10-06):** the UiKit type roles at today's sizes (#423), with no visual change, so the typeface pass changes one place.

**Alignment/typeface boundary:** do not reopen the merged Training alignment (#277) or approved typeface (#419); the broader scopes below remain open.

**Typeface DONE (2026-10-06):** the ARD Signwriter family is the game's typeface (#419). The director, after seeing the game's screens in dark at phone portrait: "Approve and merge". Drawn by the art agent (`tools/typeface/build_font.py`, original font owned by the project) and swapped into UiKit project-wide. STYLE-02 stays `TODO` for the rest of its scope: the type roles, numeral refinement and the 1/I/l, 6/8/9 and 0/O checks in real contexts.

**Scope:** establish consistent roles for fonts, size, weight, line spacing and casing in dark mode. Test names, ratings, scores and draft rows with the current Barlow family as a baseline, not a mandatory final choice. The art agent may propose suitable free/licensed replacements under existing tooling rules; the director chooses.

**Dependencies:** shared-font/component inventory and art-agent treatment; feeds STYLE-01/04/05. Do not invent a font system per screen.

**Exclusions:** paid fonts, novelty or condensed body copy without a specific approved reason, global text enlargement without composition review, rewriting player-facing content or reducing data to fit a specimen.

**Acceptance:** approved type roles are implemented consistently; 1/I/l, 6/8/9 and 0/O remain distinguishable in their real contexts; player names, score forms such as `12.8 (80)` and money amounts render without unintended clipping or wrapping; display exceptions such as score numerals are deliberate; source/licence is recorded for new fonts.

**Validation:** actual rendered 320/390 roster/score/draft specimens, real Android rasterisation at ordinary viewing distance, long names, scaling and theme rebuild. Run relevant layout/font-import checks when changing those paths. Director approves the completed typography treatment.

## STYLE-03 — Dark text/action/club-colour pairings
**Status:** `TODO` · **Priority:** `P1` · **Autonomy:** `SUPERVISED`  
**Existing owner:** §1.7 colour/shared UiKit and Match score presentation; extends M8-001/002 foundations without changing their DONE status.

**Scope:** refine red-button ink, secondary/active labels and club-coloured score figures while retaining a restrained dark palette. Colour must not accidentally imply that active information is disabled or one side's score has greater game significance.

**Dependencies:** verify current component foreground/background pairs, approved palette/typography treatment and art-agent ownership.

**Exclusions:** recolouring club guernseys, changing score/result semantics, making every label an accent, and claiming a token-level contrast calculation certifies the whole game.

**Acceptance:** final pairings work on their actual surfaces; active secondary text is recognisable; selected/disabled/danger states preserve their meaning; both teams' scores have comparable legibility across contrasting club palettes; primary actions retain the approved identity.

**Validation:** render normal/hover-or-pressed/disabled/selected components and several club pairings, including the audited COL–ESS case; calculate relevant contrast on actual fills as supporting evidence and review on Android. No need for simulation balancing when only rendering changes. Director approves final colour choices.

## STYLE-04 — Formation oval and match-screen composition
**Status:** `TODO` · **Priority:** `P1` · **Autonomy:** `SUPERVISED`  
**Existing owner:** List/FormationView and existing Match presentation; §1.6/1.7 and M8-006. Coordinate M8-003/007 art without replacing those systems.

**Scope:** refine player-name placement/scale around the formation oval and the proportion/position of match field, commentary area and controls. Blank space should feel deliberate. Compare opening, quiet, busy, scoring, break and decision states before choosing a layout; the audit's empty opening well is not evidence of an empty feed throughout play.

**Dependencies:** existing authoritative match/formation inputs, STYLE-01–03's relevant approved treatments, current art-agent work.

**Exclusions:** new gameplay, removing names/commentary/controls, an additional match engine, best-choice hints or 3D presentation.

**Acceptance:** same football identities and information remain available; names/tokens and field/control proportions are optically balanced on phones; the chosen layout works in quiet and busy states, not just a hero still; actions stay reachable and selection/match events remain unchanged.

**Validation:** native Android narrow/common/wide portrait, long names, various scores, system bars, commentary bursts, paused/break/decision states and scene return. Check relevant match/layout behaviour, event/result agreement, frame time and touch/Back. Director approves final composition.

## STYLE-05 — Distinctive headers and roster-number marks
**Status:** `TODO` · **Priority:** `P1` · **Autonomy:** `SUPERVISED`  
**Existing owner:** §1.7 bespoke art/shared headers and club markers; M8-004's menu foundation and M8-001 remain DONE.

**Scope:** start with Main, Hub and Full list. Create a consistent bespoke football identity through typography, restrained club accents, header composition and player-number marks. Keep the menu's existing content and navigation; placeholder branding is a reference, not a final approved asset.

**Dependencies:** art-agent identity proposal, STYLE-02/03, current shared-component ownership.

**Exclusions:** new portraits, invented personal histories, unlicensed club logos, additional menu destinations, decorative badge piles or a competing identity system.

**Acceptance:** the approved family is recognisable across the three screens; number marks remain distinct from ratings and real status; headers have explicit alignment anchors and work with asymmetric side controls; every club's accents remain usable in dark mode; essential navigation/touch areas survive.

**Validation:** phone captures with short/long headings, side actions, names/numbers and several club colours; first-use/returning menu, Hub prompt/no-prompt and scroll states. Check navigation/safe areas and final director appearance review.

## STYLE-06 — Consistent UI and existing football-scene styling
**Status:** `TODO` · **Priority:** `P1` · **Autonomy:** `SUPERVISED`  
**Existing owner:** **extend ARD-M8-007's existing art migration**, plus approved FL overlay/scene integration. This is not a duplicate vignette ticket.

**Scope:** align match overlays and transitions with the approved pre-rendered 2.5D figures so football scenes and menus feel like one game. Refine existing scenes and their entry/exit treatment only. Approved FL-007 permissions remain separate; STYLE-06 itself adds no new-scene authority.

**Dependencies:** approved shared 2.5D art and relevant STYLE-01–05 visual treatment; current M8-007 sequence inventory. Validate coherent supported slices without waiting for unrelated future scene families.

**Exclusions:** new tactical scenes, 3D, a second outcome model, fake participants/results or decoration that can be confused with factual game state.

**Acceptance:** existing overlays follow the approved UI language; transitions preserve participant/club identity, score/decision state and legibility; watch/skip/Back paths converge on the same authoritative outcomes; existing flavour remains visibly distinct from actionable match information.

**Validation:** capture stills and motion for the touched existing sequences, transitions and fallbacks; verify correct participants, appearances/kits, skip/touch/Back, event/outcome agreement, Android frame time/load time and existing vignette tests. Director approves final scene/overlay treatment before completion.

## STYLE-07 — PC fullscreen readability and fit-to-screen repair
**Status:** `DONE` (#371, merged; approved by the director, 2026-10-06) · **Priority:** `P0` — **EXTREME / NEXT AVAILABLE DEVELOPMENT SLOT** · **Autonomy:** `SUPERVISED`  
**Existing owner:** shared responsive layout (`ScreenLayout.gd` / `UiKit.gd`), Main/New career and other desktop screens; M8-006.

**Implementation record (2026-10-06, #371):** the director's PC is 3840x2160 with Windows DPI 288 (300%), and Godot's `screen_get_scale()` is 1.0 on Windows, so the logical canvas was the full physical size and the UI drew tiny. The fix is a desktop density of the larger of the operating system's DPI over 96 and the scale that fits 1280x720, and the first window now opens at the OS scale. Native before and after captures are in `docs/research/style07_*`; nine career_ui checks cover it. It closes only after the director has looked at it on the PC.

**Director evidence (2026-10-06):** Windows near-4K capture (original image 3822×2022, `codex-clipboard-e07bf18b-b01f-4d23-9e26-47e942a98b8d.png`) shows a tiny central New career form inside an enormous mostly empty oval/background. The director reports the game is unreadable on PC in fullscreen. Reproduce both maximised and true fullscreen modes; the captured title bar alone does not establish which window mode was active.

**Priority override:** promoted from deferred P2 wide-screen polish to an immediate P0 broken-UX repair. This specific directive supersedes the earlier instruction to do desktop work only after the dark Android styling slice. Keep phone usability intact, but do not use mobile-first sequencing to postpone making PC playable. Coordinate current shared-file owners and the art agent; existing final appearance-review gates remain applicable.

**Diagnosis lead — verify at runtime:** `project.godot` configures a 1280×720 canvas with canvas-item scaling, but `ScreenLayout._update_scale()` replaces `window.content_scale_size` with physical window pixels divided by reported density. Desktop density uses `DisplayServer.screen_get_scale()`, with a minimum of 1. If Windows reports 1 on a large/high-resolution display, the logical viewport grows to nearly physical resolution and fixed UI type/control sizes remain tiny relative to the screen. `UiKit` has a 15-unit body / 24-unit H1, and `Main._show_setup()` caps the form at 440 logical units. This fits the symptom but is a code-based hypothesis, not a measured diagnosis of the director's machine. Capture window size, actual logical viewport, effective scale, OS DPI and display scale before selecting the fix.

**Scope:**
- Repair the shared desktop scaling policy so default text, controls, Back and dialogs are comfortably readable at normal monitor viewing distance in fullscreen/maximised mode, including high-resolution screens and Windows scaling settings.
- Fit content purposefully to the available screen. A short setup form may remain centred with sensible margins, but must not stay a tiny island; wider information screens should use deliberate group widths, columns and gutters, with coherent label/value pairing.
- Use one consistent scaling/layout route across menus, club selection, hub, lists, coaching, training, match preparation, match/quarter breaks, results and settings. Avoid one-screen font overrides, double DPI scaling, distorted aspect ratios or stretching every paragraph across the entire monitor.
- Handle fullscreen/windowed transitions, resizing and monitor/DPI changes without losing selections, scrolling, modal state or click alignment.
- Preserve Android portrait/landscape layout, touch targets, safe areas and mobile text sizing. Preserve the established visual identity and football/save state.

**Dependencies:** inspect current shared layout and relevant in-flight UI changes. The broader STYLE-01–06 redesign is not a prerequisite for this bounded repair.

**Acceptance:** PC is readable by default without reducing desktop resolution or shrinking the game window. The New career form and primary actions are appropriately sized, all essential content is reachable, no important text/control is clipped, and mouse hitboxes align with visuals. Resizing and fullscreen toggling retain usability and state. Long labels, names, dialogs and busy screens fit or scroll deliberately. Phone presentation remains usable.

**Validation:** native Windows before/after captures at 1920×1080, 2560×1440 and 3840×2160, plus a smaller window and representative ultrawide aspect; check available Windows display scaling settings (100%, 125%, 150%, 200%) without applying scale twice. Include maximised and true fullscreen, a mode toggle, New career plus representative dense screens and a modal, long names, scroll and click/focus checks. Recheck narrow phone portrait and landscape. Use focused shared-layout tests and existing required CI; headless viewport checks alone cannot prove native DPI readability. Obtain the director's final PC appearance/usability review before marking DONE.

## STYLE-08 — Lower-priority light-mode maintenance
**Status:** `TODO` · **Priority:** `P2` · **Autonomy:** `SUPERVISED`  
**Existing owner:** shared theme/illustration foregrounds and M8-006.

**Scope:** after dark work, repair identified light-theme logo/button/role-label/grass-label/score-ink pairings that still reproduce. Use dedicated foreground/background pairs so fixed-colour football art does not inherit inappropriate global text. The director included this maintenance while retaining a strong dark preference.

**Dependencies:** established dark styling, current theme inventory and art-agent approval path. Not a dependency for shipping an approved dark slice.

**Exclusions:** a fresh light redesign, changing the default/user theme preference, inventing a second identity, or diverting the primary dark-mode budget.

**Acceptance:** the identified pairings are legible and coherent; theme switching/rebuild preserves control states and dark appearance; final light treatment remains in the same approved family.

**Validation:** representative light phone captures, fixed-grass labels, logo and contrasting club scores, active/disabled buttons, theme toggle/reload and targeted appearance checks. Recheck affected dark components. Director approves the final maintenance result.

## Shared execution and completion gate

STYLE-07's base desktop-scaling repair (#371) and the narrow Training-row alignment (#277) are already DONE. Verify any current recurrence before changing them. Under the refreshed §0.4.1 queue, have the art agent lead a coherent dark typography/colour/control slice (STYLE-01–03), extend composition/identity (STYLE-04/05) and integrate existing scenes (STYLE-06). Supported independent slices may proceed after their own prerequisites. The earlier STYLE-07 start instruction is historical and fulfilled; remaining desktop composition defects and light work follow their own acceptance scope. This is not a mandate to complete a global redesign before delivering a useful repair.

Hold content/state constant when comparing style treatments. Keep normal, selected, pressed, disabled, short/long, empty/busy and real club variants. Player sessions can assess perceived polish and readability; simulations do not establish beauty or enjoyment. Styling must not modify football results, save formats, draft/contract state or progress.

For each slice record current-code evidence, art-agent direction, director's final decision, changed files, relevant checks, phone findings and merged commit. Use targeted engineering checks and the existing CI/phone gates; do not create pixel-exact tests that merely encode subjective taste. `DONE` requires approved appearance, validated implementation and verified `main`, not approval of this roadmap.

The eight includes are the complete decision record. There are no rejected style candidates to leave in Claude's queue, and no new gameplay or flavour candidates are authorised by this interview.




