# Aussie Rules Dynasties — dark-mode visual style audit and sports-sim research

6 October 2026 · Research plus completed director interview · **All eight work scopes included; final visual treatments still require director approval**

## Executive finding

The current dark UI has a useful foundation: warm black, off-white type, restrained red actions, flat surfaces and recognisable football elements. Its weakness is that this foundation has not yet become a consistently bespoke game identity. Some screens look like an authored football publication; others look like ordinary forms assembled from the same handful of rectangles.

The most promising direction to investigate is a football-specific editorial interface with deliberate composition, confident typography and a small family of distinctive controls. That is a hypothesis for the art agent and director, not a replacement art direction. The art agent has higher authority than this audit on visual direction; the director makes every final decision.

**Dark mode is the primary design and validation target**, following the director's explicit preference during this research. Light-mode observations are retained in a short appendix. They must not consume the attention intended for the main experience.

The strongest player evidence argues against universal rules such as “bigger is better”, “more blank space is cleaner” or “a fashionable font makes a modern UI”. Players of FM, OOTP, FHM and MLB describe contrary preferences, often tied to screen size and the particular implementation. The useful lesson is to author proportions for the intended device and test the actual lettering, backgrounds and controls together. See P01–P18 in the [source ledger](AFL_UI_STYLE_SOURCE_LEDGER.md).

This report studies **colour, lettering, shape, positioning, blank space, proportion and visual identity**. It does not recommend cutting game information, simplifying rules or restructuring the career to address information overload. A sparse interface can still have the wrong style.

## Authority, boundaries and existing work

- The director approves all final decisions. Art-agent visual decisions outrank this researcher's recommendations.
- The completed director interview included all eight STYLE-01–08 scopes. They are now accepted work packages under [canonical roadmap §9.5](../roadmap/23-9-5-approved-visual-styling-work-director-interview-2026.md#95-approved-visual-styling-work--director-interview-2026-10-06); no suggestions were rejected. Final visual treatment remains the art agent/director's decision. No implementation is claimed.
- AFCM and Footy Redraft are explicit negative aesthetic references under the current roadmap. Their strengths in gameplay do not make their interface shapes, colours or composition aspirations.
- Current roadmap §1.7 already identifies a visual anti-slop reset, bespoke art tooling and free-font sourcing. This audit supplies evidence to those owners; it does not create a parallel redesign project.
- Current UiKit uses Barlow and Barlow Condensed. That is a description of the captured implementation, not a veto on the art agent selecting another licensed font.
- Existing approved 2.5D vignette migration and FL flavour work remain separate. This audit neither revokes them nor authorises new tactical scenes, 3D rendering or a trailer.
- Premium purchase, zero MTX and enjoyment-first remain the product constraints. Commercial storefront patterns are not a reference goal.

Baseline authority: [pinned roadmap](https://github.com/gabebartolo-spec/Afl-auto-battler/blob/75bb24ee5c987bd1fcaf21d22e02c92b876b4823/docs/ROADMAP.md), especially §§1.6–1.8 and ARD-M8-007; [pinned project instructions](https://github.com/gabebartolo-spec/Afl-auto-battler/blob/75bb24ee5c987bd1fcaf21d22e02c92b876b4823/CLAUDE.md).

## Method and evidence strength

### Current-game audit

Snapshot: `gabebartolo-spec/Afl-auto-battler` main at **75bb24ee5c987bd1fcaf21d22e02c92b876b4823**. Later art-agent work may supersede individual findings; verify against the current build before repairing anything.

A disposable source copy was imported and rendered with official Godot 4.7 on Windows using the compatibility renderer. The audit captured **74 PNGs** across dark/light themes and logical windows of **320×720, 390×844 and 1280×720**. Ten routed screens were captured, plus full-list and draft-board states; the player sheet was captured at 390 in both themes. The final run completed without reported script errors. Contact sheets and selected native-resolution frames were visually inspected.

The fixture uses the existing COL club-list entry point, generated display names and a seeded COL–ESS match. The draft capture exercises the existing league-redraft board. This is not a validation of the future inherited-2026-list mode. Saving was disabled and scratch settings were directed into the disposable copy. Small differences in contract prompts, selected draft position and roster order arise from fixture state; these are not theme differences.

These are **Windows-rendered Android-oriented layouts**, not screenshots from the director's Android device. Logical dimensions are not physical phone pixels. Font rasterisation, brightness, touch, navigation bars, outdoor visibility and actual mobile performance still require native Android review. The match capture is the opening frame; it cannot establish how the commentary region looks during a busy match or how a vignette reads in motion.

### External research

The evidence ledger separates **19 directly read primary player records**, four weaker indexed player records, supporting critical/developer accounts and seven visual-inspection records. One of the visual records was rejected because the first official SMB4 still contained no UI. The primary records include Reddit, Steam discussions/reviews, OOTP/FHM developer forums, Cricket Captain's community forum and player comments under a specialist racing review.

The deeper comparisons concentrate on FM, OOTP, FHM, Cricket Captain, F1 Manager, Motorsport Manager, Golden Lap, FTG, MLB and Madden. WAF, Tennis Manager, FOF, PCM and Kairosoft/Retro Bowl provide lower-confidence contrasts. This is deliberately broader than one sport or one aesthetic school. It is not a sales ranking: “major franchise”, “enthusiast reference” and “smaller contrast” are sampling roles, not verified market-leadership claims.

Evidence labels used below:

- **Observed:** visible in an inspected image or current source/capture.
- **Player account:** reported by a player; not independently reproduced or representative of all players.
- **Developer interpretation:** stated goal or explanation, not independent validation.
- **Critical account:** journalist/reviewer interpretation, supporting rather than primary.
- **Hypothesis:** an adaptation proposed for ARD, requiring art-agent assessment and director approval.

No competitor was played hands-on. Complaint threads overrepresent dissatisfaction; skin threads overrepresent players motivated to customise. Repetition is useful for discovering a failure mode, not for estimating its prevalence. Source edition and platform are preserved rather than treating an old launch complaint as a current universal defect.

## Dark-mode audit: what already works

### 1. The base colours have character

The background is warm near-black `#121110`, ordinary type `#F1EEE6`, panels `#1B1A17`, outlines `#363229`, secondary type `#A39E93` and primary red `#C8412B`. This avoids the default navy/teal productivity-app palette already rejected by the director. The small warmth difference matters: the interface feels closer to ink, print and evening football than a generic data product. **Observed palette; emotional description is this audit's interpretation.**

The risk is not that these colours are wrong. It is that nearly every ordinary control inherits the same outline, fill and size, leaving the screen with too little authored variation. Replacing all colours without examining composition would miss the problem.

### 2. Some pages already feel editorial

Staff uses names, small role captions and horizontal rules without enclosing every person in a card. Coaching uses direct label/value alignment. The full list gives names visual priority and places rating figures at a stable right edge. These show how the game can feel structured without adopting a dashboard-card aesthetic.

These are useful internal reference pages for the art agent. Their exact font, spacing and dimensions are not being declared final.

### 3. Football remains the visual subject

The oval, centre square, interchange strip, club colour bands, guernsey numbers and score figures make some screens unmistakably football-specific. The match opening places the oval above the transport controls. The title's assertive lettering and red script have more identity than a generic app heading.

The logo is explicitly a placeholder asset. Its strongest qualities can inform identity review, but treating it as final would ignore both its source status and the art agent's remit.

### 4. Restraint is real, not just policy

There are no decorative glass panels, chart gradients or general-purpose glows in the inspected dark screens. Corner radii are capped at six logical units by UiKit, even where individual callers request larger values. Some surfaces therefore look rounded, but this is not evidence of actual 12–20-unit corners or pill-shaped panels. The issue is their repeated silhouette and arrangement.

## Dark-mode audit: material findings

**Director-confirmed defect:** the player-row text in the dark Training screenshot is off-centre. The name/secondary-line stack sits too high inside its row, while the role and rating sit nearer the middle. This uneven vertical alignment is a concrete defect, not merely an aesthetic preference. The art agent determines the treatment and the director approves the final result.

| Finding | Evidence | Visual consequence | Confidence and proposed review |
|---|---|---|---|
| Repeated outlined row boxes dominate Training and Selection | Native 320 Training; 390 contact sheet | Similar rectangles compete visually; the rhythm feels like a form rather than a football game | High observation, aesthetic judgement. Art agent should compare an alternative treatment with identical information and hit areas. |
| Training player text is vertically off-centre | Native 320 Training; director explicitly identified the player-row text | Name/secondary stack is top-heavy while role/rating are nearer row centre | Director-confirmed defect. Centre the information stack optically within the row while retaining left-aligned names and consistent columns; final treatment goes through art agent/director. |
| Full-list styling and Training styling diverge | Same player's list row versus training row | One uses open editorial rows, the other nested outlined boxes | High observation. Decide which visual grammar fits each purpose rather than imposing one component blindly. |
| Match opening contains a large empty lower well above controls | 390 opening frame | The field and controls look separated by a vacant dark container | High for opening only. Review opening/quiet/busy frames before changing height or placement. |
| Oval labels become very small at narrow portrait sizes | Native 320 list shape | The football diagram is prominent while names/roles are visually delicate | High observation. Test glyph scale, stroke and token/name spacing; do not treat this as permission to delete player identities. |
| Shape panel allocates generous vertical space around a width-limited oval | 320/390 versus 1280 | On phone, blank space surrounds a relatively small oval; on desktop the oval fills its pane | High observation. Compare purposeful framing versus accidental centring before declaring space “wasted”. |
| Wide Coaching stretches values far from labels | Native 1280 Coaching | A large gulf weakens visual grouping despite low content density | High observation. A desktop composition constraint could help; Android remains the priority. |
| Hierarchy and casing vary across screens | Training's uppercase role tabs; league-redraft's large condensed uppercase heading; ordinary centred headings elsewhere | Screens feel assembled under different typography rules | High source/image evidence. Reconcile with the art agent's typography system; score/display exceptions can remain deliberate. |
| Normal text sizing is not consistently routed through the named scale | UiKit BODY=15 but lbl default=16; numerous page-specific sizes | Neighbouring screens subtly vary in optical hierarchy | High source evidence. Not all variations are errors; inventory intentional versus accidental choices. |
| Red actions have less text contrast than ordinary copy | Exact token calculation below | Small action labels can feel thinner/weaker than body copy | High token evidence, device impact untested. Review ink and red shade together. |
| Club colours can give equal teams unequal score emphasis | COL score grey, ESS score white in match capture; score ink comes from team palette | Numerals have different apparent weight/brightness | High for fixture. Test several club pairings; do not infer an intentional game state from this difference. |
| Several active secondary lines use very faint treatments | List POT line and fine print; source colour tokens | Metadata can look disabled even when useful | High observation; classify each line before changing it. Disabled controls legitimately use a different treatment. |
| Most headers rely on a generic centred title/back/action pattern | Contact sheets | Clear navigation, but limited distinctive composition between modes | High observation, subjective consequence. Bespoke header treatment is an option, not an approved global replacement. |

### Alignment requires explicit anchors

The director's flagged issue is the **Training player row**, not the heading. `TrainingScene._player_row` creates a 58-unit button with a full-height horizontal container. The name and secondary line live in a vertical container with no explicit centring of the stack. The capture shows that stack sitting high relative to the role/rating. Review the whole information stack's vertical position, not just the alignment property on each text label.

There is a separate potential header issue: the current top bar centres its title inside the space left between its side controls. A 44-unit back control and a wider right action do not guarantee that the title is centred on the screen. That is a source-derived review concern; it is not the defect the director identified.

For any approved repair, define what is centred against what: screen, content column, available label area or row. Also specify whether alignment is geometric or optical. Do not solve a misplaced heading by shrinking the right-hand action, or centre every roster label indiscriminately. Names can remain consistently left-aligned while the information stack is vertically balanced within its row.

### Palette and contrast, with limits

The base text/background pair is strong: **16.27:1** for `#F1EEE6` on `#121110`. The primary red button uses that same text colour on `#C8412B`, giving approximately **4.26:1**. The dark faint token `#6E695F` on the base background is approximately **3.46:1**. The ordinary dark formation label on the fixed grass is approximately **7.62:1**.

These are calculations from exact source RGB values, not sampled anti-aliased edge pixels. Actual role labels and secondary text can sit on panel fills or partially transparent surfaces, so each final component needs its own calculation. A contrasting outline/shadow can alter a particular rendering; the numeric table does not model that.

WCAG's ordinary-text reference is 4.5:1, with different provisions for sufficiently large text and exceptions such as inactive controls. Use it here as a useful benchmark for small game labels, **not a claim of formal whole-game compliance or noncompliance**. The 4.26 ratio deserves review because typical button labels are small. It does not prove a player cannot read them. [W3C explanation](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

The art agent should set pairings rather than choosing a red swatch alone. A slightly different red, dedicated on-action ink or adjusted weight may retain the intended identity. This report does not choose one.

### Type and numerals

The declared scale is 24/18/15/13/11. Barlow regular and semibold supply normal labels; Barlow Condensed Bold supplies score figures and some display headings. This is coherent enough to serve as a baseline, but not consistently applied. The league-redraft heading is much more forceful than ordinary page titles; Training mixes a large list heading with tiny role lines and uppercase abbreviated tabs.

Test actual problem strings: 0/O, 1/I/l, 6/8/9, 75/95, 0.0 (0), 12.8 (80), hyphenated surnames, initials, club names and monetary amounts. Assess numeral distinguishability, weight and line spacing at normal viewing distance. Do not shrink or enlarge all text globally based on one desktop screenshot.

The score's condensed character can be a deliberate broadcast exception. Condensed everyday metadata, stylised body digits or pervasive italics would need stronger justification. Player criticism in SMB4 and MLB24 is especially useful here because it identifies concrete lettering failures rather than simply asking for less information. P07/P08.

### Shapes and repeated components

A radius of six does not guarantee that a screen avoids app-template aesthetics. Repeated outlined boxes, nested groups, identical action silhouettes and uniform padding can produce that feeling even with modest corners. Conversely, a small rounded corner on one useful control is not itself a failure.

Compare Training with Staff while keeping content unchanged: the latter establishes grouping through typographic relationships and rules; the former repeatedly puts each row inside a button-like enclosure. The art agent should determine whether row dividers, tabs, roster-number treatments or another bespoke football motif can communicate interactivity with less repetitive framing. Touchable areas must survive any visual restyling.

Avoid the opposite overcorrection: putting every button in a sharp bevel, torn-paper sticker or giant ticket would merely replace one repeated template with another. Bespoke means an intentional system of purpose-specific treatments, not maximum ornament.

### Blank space and proportions

Blank space is assessed by relationship, not percentage. Staff's quiet lower area allows names to read cleanly. Coaching's full-width desktop label/value gulf weakens pairing. The shape screen's margins frame the oval but also make the player labels feel miniature relative to the container. These require different decisions.

In the match opening, the lower feed well is visually vacant before play. That does not show it is vacant throughout the match. The proposed comparison must include an opening frame, ordinary play, a scoring burst, a break and a decision overlay before choosing a new proportion. No simulation change is needed to test those compositions.

Margins also differ: Main uses 16 logical units, many pages 12, Match 10. Different margins can be sensible where the oval needs room; the issue is whether the difference is optically deliberate. A strict universal margin is not automatically more beautiful.

## Screen-by-screen dark-mode review

| Screen | Preserve as evidence of a useful direction | Review with the art agent | Do not infer from these captures |
|---|---|---|---|
| Main | Strong title contrast, restrained red, confident empty space, faint oval motif | Placeholder logo, title/control balance, bespoke action silhouette | That the placeholder is an approved final identity |
| Hub | Opponent heading, club band, editorial ladder, anchored lower actions | Uneven visual weight when a contract prompt appears; relationship between secondary and primary actions | That every career displays the same prompt |
| List: shape | Recognisable oval and interchange strip | Player/name scale, surrounding space, visual distinction from match view | That logical 320 equals a physical Android pixel grid |
| List: full | Names lead; stable right-aligned figures; roster-number marks | Secondary type, row height/weight, separation between groups | A reason to remove the ratings or player details |
| Selection | Clear headings and neutral hierarchy | Repeated outlined player boxes, typography/casing and header identity | A need to redesign the selection mechanic |
| Training | Restrained role colour, clear name/rating relationship | Director-confirmed off-centre name/secondary stack; nested framing, uppercase tabs, row silhouette and tiny secondary copy | Permission to change training outcomes |
| Coaching | Plain label/value pairs and restrained selected state | Desktop width, button-grid silhouette, vertical rhythm | That the tactical choices themselves are ineffective |
| Ladder | Club colour stripes and stable numeric columns | Optical row spacing and headings at phone size | A need for another analytics page |
| Staff | Open rows, name emphasis and thin separators | Amount of character/club identity consistent with new art direction | Permission to invent portraits or personal histories |
| Player sheet | Name/role hierarchy and clear large figures | Fine-print weight, relationship of bars to prose, full-width Close treatment | Whether all scrolling/motion states perform correctly |
| Match | Field-led opening, strong score numerals, quiet control palette | Team-specific ink brightness, transport geometry, feed/field proportion | Busy-match/vignette motion quality |
| League redraft | Clear mode distinction, stable pool/row relationships | Oversized uppercase display heading versus standard pages; repeated outlined filters/actions | A defect in the future National Draft start mode |

## Competitor deconstructions: players first

### Football Manager: one brand, several incompatible ideas of “clean”

**Player accounts:** the default-skin thread contains admiration for the original's restraint alongside strong preference for particular mods. The FM24 skin discussion praises Tato's elegance and avoidance of flashy colours, while other replies value club colours and larger player photos. Particular skins are described as oversized, unpleasantly coloured or cramped. A laptop user finds an attractive skin too crowded. These opinions do not establish a winning skin; they demonstrate device- and taste-sensitive styling. P01–P03.

**Observed visual:** FM26's representative portal uses navy/violet, framed panels, condensed section headings and a prominent gradient Continue action. It is clearly branded, but its card-led vocabulary conflicts with ARD's current director constraints. The image is explicitly pre-release representative UI, not proof of the final build. V05/S01.

**ARD hypothesis:** borrow consistency of type roles and meaningful club identity, not the portal composition. Ask players to judge the same ARD layout at phone scale before concluding that larger portraits, wider gutters or thicker frames improve it. Do not import a desktop skin wholesale.

### Out of the Park Baseball: highly engaged players still argue about font size

**Player accounts:** the OOTP27 discussion combines praise with complaints about new colours and readability. Within the same discussion, players have opposing size preferences. OOTP24 reports involve clipping and centring on particular desktop configurations; an OOTP25 user describes a frustrating crisp-small/fuzzy-large scaling trade-off. These are edition-specific accounts, not proof that current OOTP universally renders poorly. P04–P06.

**What this tells us about style:** typography is a rendered product of font, size, weight, scaling and background. A font that looks convincing in a design board can still look soft or poorly fitted in the shipped game. No specific OOTP font diagnosis or engine explanation is adopted as fact.

**ARD hypothesis:** inspect actual Godot output at intended logical sizes and on Android. Treat correct centring and consistent optical weight as visual polish, not merely bug fixing. Replacing the font is one possible art decision, not a substitute for testing its rendering. OOTP's tables are not the primary-screen visual aspiration.

### Franchise Hockey Manager: long-term attachment does not erase styling concerns

**Player accounts:** a self-described long-term FHM player prefers FHM9's font on a laptop to FHM11's and asks for font/skin choice. Another reports blur, overlap and small text; an ultrawide player explicitly disagrees and describes substantial improvement. Their claimed hours and hardware are self-reported. P18.

**Critical context:** older FHM reviews separately describe organised or bright presentation alongside sterility or tiny icons. Those accounts concern older editions and cannot validate the modern game. S11/S12.

**ARD hypothesis:** preserve visual personality without making basic lettering depend on a particular monitor. The useful test is whether a new type treatment survives small portrait screens and overlays. Offering an entire skin ecosystem would be a major new feature and is not justified by this narrow evidence.

### Cricket Captain: familiar styling can be clean yet awkwardly proportioned

**Player accounts:** the 2025 mobile discussion includes appreciation for its new look but specific objections to narrow controls, unused gaps, faint form stars and phone/tablet placement. The older discussion raises lettering/colour concerns. P16/P17.

**Observed visual:** the player-annotated 2025 attachment shows a landscape layout with white slanted bars, blue headings, grey tabular surfaces and a detailed illustrated icon rail. Red strokes on the screenshot are the player's annotations. Its distinctive cricket character does not make it a suitable direct portrait-Android template. V06.

**ARD hypothesis:** compare where blank space sits relative to the subject and controls, not whether a screen has any gaps. Bespoke sport-specific bars/icons can provide identity, but their detail must survive actual phone scale. Test footer geometry against system bars. Keep the player's praise and criticism together rather than presenting the thread as a rejection of the redesign.

### Motorsport Manager: flat can still feel like a game

**Player account:** one Steam commenter specifically appreciates the new flat interface and wants it retained. This is a valuable positive example, but only one explicit styling comment. P14.

**Observed visual:** the official HQ still makes its rendered campus the subject, with a dark translucent side panel, flat lower navigation and a clearly different yellow Continue action. The interface does not need to fill every region with a card. This is a PC HQ screenshot; it is not evidence about a race HUD or Android layout. V02.

**Critical counterpoint:** historical mobile coverage describes cramped phone presentation and overly spread-out tablet presentation, while other reviews praise clarity. These accounts involve different versions. S06–S08.

**ARD hypothesis:** visual subject, controls and space can be designed together without a generic dashboard grid. Study the balance, not its 3D campus, exact translucency or yellow palette. Existing 2D/2.5D constraints remain authoritative.

### F1 Manager: prestigious presentation does not settle scale and placement

**Player accounts:** complaints about large widgets and an ultrawide HUD's centre placement contrast with weaker indexed launch praise for a clear interface. The latter direct page fetch failed and receives lower weight. Desktop/ultrawide criticism is not a phone specification. P11–P13.

**Observed visual:** the inspected livery-editor still uses a dark blue/violet stage, left swatch column, bottom mode control and a large car. White marks selected controls. It establishes a focal object without making every region equally emphatic. This was the livery editor, not the race screen. V03.

**ARD hypothesis:** the oval and approved vignette art should remain strong visual subjects. Control framing and alignment should support them. Keep decisive action text visually distinct, but do not copy F1's panels, switch to 3D or add racing-style instrumentation. Test specific ARD states before changing feed/field proportions.

### Golden Lap: small-budget coherence is a useful contrast

**Player accounts:** a specialist review commenter praises the minimal functional art style; another appreciates its details. A new Steam player calls it beautiful and fun while still being confused by mechanics. Aesthetic simplicity therefore cannot be assumed to explain rules. P19/P20.

**Observed visual:** the rainy race still uses a pale landscape, compact neutral standings on the left, coloured position circles and red-outlined messages on the right. Subject and interface have a coherent graphical vocabulary. V01.

**Critical counterpoint:** a review flags small text despite appreciating the presentation. S04.

**ARD hypothesis:** coherent restrained art can feel authored and playful without a large production budget. Borrow that discipline rather than a pale palette, exact rounded controls or minimal race symbols. Dark ARD can achieve its own coherence through spacing, lettering, club markings and approved art. It must prove that small labels remain readable rather than equating minimalism with tiny type.

### Football, Tactics & Glory: characterful geometry with real transition risks

**Player accounts:** an older redesign thread mixes praise with complaints about inconsistent old/new styling, small lettering/icons and empty gutters. It is historical evidence about a transition, not the present game. P15.

**Observed visual:** the inspected match image uses a green field, compact scoreboard, yellow angled actions and outlined names/arcs. Character and control geometry belong to a visibly game-like world. Some bright overlay combinations would need separate legibility testing before adaptation. V04.

**Developer account:** the FTGW article describes an aspect-ratio rewrite and attempts to show more players without reducing readable text. That is a design goal, not independent proof of enjoyment or a statement of current shipping status. S02.

**ARD hypothesis:** migration consistency matters. A beautiful new art-agent header beside old generic row controls can still feel unfinished. Sharper football-specific treatments are worth exploring; yellow slanted buttons and tactical overlays are not prescribed.

### Super Mega Baseball 4: expressive typography can become a constant irritant

**Player accounts:** players criticise pervasive italics/slanted lettering, gradients, transparency and selector clarity, while some explicitly enjoy the gameplay. This is a negative-selected thread rather than a consensus. P07.

The first official still inspected in this session had **no UI**, so it does not support interface observations. No invented screenshot comparison is used. V07.

**ARD hypothesis:** confine expressive lettering to identity moments and test each ordinary numeral. Avoid layering important labels over visually active football art merely because it looks attractive at desktop size. ARD's red title script can coexist with straightforward controls. The art agent decides how much expression is appropriate; this evidence only identifies the risk of making expression pervasive.

### MLB The Show 24/25: a style can be loved and hard to read

**Player accounts:** the 24 discussion names ambiguous digits and branding/background problems, but another participant likes the graffiti aesthetic. The 25 first-impressions thread contains sleek praise, bulky-font reactions and a milder busy-colour complaint. These are different releases; they are not a longitudinal controlled test. P08/P09.

**Critical support:** bright-menu reporting discusses pale-background contrast, but personal discomfort reports are not clinical evidence. S05.

**ARD hypothesis:** seek distinctiveness in composition and identity while keeping ordinary digits unambiguous. Test the complete scoreboard and roster row, not a font specimen. Bigger text can help recognition while making the interface feel heavy; finding the right proportion matters more than automatically maximising it. Do not import licensed-show branding or monetised menu layouts.

### Madden: aesthetic praise and sluggish menus can coexist

**Player accounts:** a Madden25 player strongly praises the menu appearance and new font; replies describe slow menus and portrait loading. P10.

**ARD hypothesis:** assess style and responsiveness as separate attributes, then verify they coexist. More character art is not automatically better if it introduces visible loading, but the thread does not prove portraits are the cause or that ARD should avoid them. Any art-agent proposal should be rendered at phone scale and tested within the existing performance gates. The paid-card ecosystem is outside scope.

### We Are Football: bright, distinct and contested

The stronger style evidence here is limited. An indexed WAF2024 player review praises its interface, while 2021 reviews provide contrasting favourable aesthetic and colourful/cluttered accounts. These editions and source types must not be collapsed into one verdict. P21/S09/S10.

**ARD hypothesis:** energetic sport-specific styling is not guaranteed to look tasteful; visual busyness can arise from colours, borders and ornament even with unchanged information. Use identical content when comparing candidate styles. WAF is a contrast case, not a source for new screens or controls.

### Lower-confidence breadth: Tennis Manager, Front Office Football, PCM, Kairosoft and Retro Bowl

These sources do not have the same depth of direct player-style evidence in this session and should not drive decisions.

| Reference | Supporting account | Carefully limited ARD question |
|---|---|---|
| Tennis Manager 2024 | Review praises layout while finding match presentation weaker; S14 | Does a polished menu still feel connected to the visual football world? |
| Front Office Football 7 | Older review finds the interface functional but plain; S15 | Can ARD preserve functional precision while gaining authored personality? |
| Pro Cycling Manager 2020 | Older review discusses familiarity and refresh limits; S16 | Which visual conventions help returning players, and which merely preserve dated appearance? |
| Pocket League Story | Critical appreciation for pixel-art character; S17 | Can controls and art share one world without adopting pixel art or copying Kairosoft? |
| Retro Bowl | Indexed player appreciation for familiar uncomplicated layout, and a separate scanline dislike; P22/P23 | Can nostalgic identity survive without filters that some players find distracting? |

These are research leads for further reference gathering if the art agent needs them. They do not justify declaring those games universally beautiful, changing ARD's art medium or treating nostalgia as a shortcut to a bespoke interface.

## Cross-game synthesis: what is defensible

| Dimension | Evidence pattern | ARD interpretation to test |
|---|---|---|
| Colour | Players praise restraint or club identity, but object to particular contrast/busy combinations | Keep dark surfaces calm; deliberately assign action, club, status and decorative colours rather than colouring every box |
| Typography | Specific fonts/digits divide players; scaling can undo a good font choice | Judge complete rendered strings on Android, not brand prestige or font popularity |
| Shapes | Flat presentation can be liked; repeated frames and overly large controls can feel heavy | Create a small purpose-specific family of silhouettes; preserve touch areas without making all hit areas visible cards |
| Positioning | Desktop-centred HUDs can obscure the subject; phone/footer placement creates different problems | Author portrait composition first, then a separate optical arrangement for wide screens |
| Blank space | Some players want more room, others find the same skin wasteful or cramped | Examine space adjacent to the subject/control; avoid global “add padding” or “fill gaps” fixes |
| Proportion | Larger text can be praised as readable and criticised as bulky | Tune names, numbers, headings, buttons and art as a relationship |
| Identity | Club colour, portraits and sport-specific art can build attachment | Make ARD recognisably football-specific without every screen becoming a branded poster |
| Consistency | Old/new visual mixtures attract criticism | Plan complete states for a small approved slice before spreading partially applied styling everywhere |

The confidence is strongest in **specific failure modes**: ambiguous lettering, weak foreground/background pairing, inconsistent treatment, poor device scaling and unbalanced object/control relationships. Confidence is weaker in subjective prescriptions such as a particular palette, font or amount of ornament.

## Completed director interview — accepted work scopes

The director answered **Include** to each STYLE-01 through STYLE-08, in order. The canonical roadmap now uses these stable IDs as scoped work packages under existing UI/art owners. All eight are accepted; there are no rejections to carry forward. This approves the work scope, not a particular visual solution. The art agent leads visual treatment and the director makes every final decision.

| ID | Candidate | Smallest reviewable experiment | Benefit / trade-off | Existing owner and approval boundary |
|---|---|---|---|---|
| STYLE-01 | Bespoke dark-mode control grammar | Two Training/Selection treatments with identical data, positions and hit areas; compare row silhouette, rules and corner treatment | More authored identity; risk of weakening perceived interactivity | §1.7 art/UI reset; art-agent proposal, director selection |
| STYLE-02 | Dark typography and numeral specification | Type specimens plus real roster, score and draft rows at 320/390; include current font as baseline | Coherent optical hierarchy and recognisable digits; risk of novelty or excessive bulk | Art-agent free-font remit; no replacement font selected |
| STYLE-03 | Action/metadata/club-ink pairings | Swatches rendered in actual controls, plus COL/ESS and additional contrasting club scores | Stronger labels without losing restrained dark palette; risk of too much emphasis | Shared UiKit/presentation owners; director approves visual result |
| STYLE-04 | Phone oval and match-frame composition | Existing data in opening, quiet, busy and break frames; compare field/feed/control proportions and formation-name placement | More confident visual football subject; risk of crowding or losing calm | Existing Match/List UI and M8 art context; no new gameplay |
| STYLE-05 | Distinctive headers and roster-number marks | Main, Hub and Full list in one proposed family; club variations as small accents | Recognisable identity through composition; risk of decorative repetition | §1.7 bespoke art direction; no new portraits or licensed assets implied |
| STYLE-06 | Consistent art/UI transitions | One existing approved 2.5D scene entering/leaving the match, with overlays in the proposed UI style | One visual world across menus and football; risk of motion/performance regressions | ARD-M8-007/approved FL owners; no new scene authorisation |
| STYLE-07 | Wide-screen optical layout | Coaching/List at 1280 with constrained group widths and purposeful gutters | Better visual pairing; lower priority than phone work | Existing responsive layout; director chooses whether worthwhile |
| STYLE-08 | Optional light-theme maintenance | Address already-observed ink/logo pairings only if the director later prioritises it | Avoid theme-specific breakage; must not divert dark-mode effort | Separate low-priority appendix, not a dark-mode dependency |

The inclusion is explicit interview approval, not inferred from earlier work. See roadmap §9.5 for dependencies, exclusions, acceptance, validation and visual-approval gates. Statuses remain TODO until implemented and verified.

**Separately confirmed:** the Training player-row vertical-alignment defect is included as a KNOWN BUG subtask of STYLE-01. It may be repaired independently of the broader control restyle; its final treatment remains subject to art-agent/director review.

## Validation for an approved styling slice

1. **Art-agent review first:** identify which captured findings remain current; propose one or two internally coherent treatments, using unchanged content and authoritative existing art. Record fonts/assets and licences if introduced.
2. **Director selection:** present normal-size dark phone captures of the actual proposed slice, including every relevant state. Do not ask the director to approve a mood board as if it validates the implementation.
3. **Style-only comparisons:** hold the roster, names, results, controls and wording constant. Otherwise a preference for better content can be mistaken for a preference for styling.
4. **Phone observation:** at ordinary viewing distance, ask players which screen feels more authored, which has more appealing proportions, which text is awkward and whether a control looks interactive. Ask open explanations after the initial choice; do not coach them into the desired answer.
5. **Native Android gate:** review dark mode at narrow/common/wide portrait sizes, actual system bars, normal brightness and both stills/motion. Verify text rasterisation, hit areas, scrolling, frame time and transitions. Existing correctness gates remain intact.
6. **State coverage:** normal/selected/pressed/disabled controls; short/long names; neutral/success/failure copy; no-news/busy-news; opening/quiet/busy match; different club colours; first-use and returning-use screens.
7. **Record disagreement:** retain preferences by device and context. A handful of sessions does not establish population-wide taste. Do not declare an option “proven beautiful” from a majority of a tiny convenience sample.

Suggested participant mix: current ARD players, experienced sports-management players and football fans less comfortable with management games. This is a recruitment proposal, not completed testing. Player enjoyment, perceived polish and desire to return are important outcomes, but this audit has not measured them.

Keep an approval log distinguishing **observed problem**, **art-agent treatment**, **director decision** and **verified build**. Screenshots in this report are baseline evidence, not approval of their appearance.

## Light-theme appendix — secondary priority

The light captures reveal specific pairing problems: the placeholder's pale title fades into its background; primary-button dark ink on red is approximately 3.03:1; unchanged pale role colours look weak on cream; formation labels inherit dark UI text over dark grass; COL/ESS score ink is faint on the light scoreboard. These are visible implementation issues rather than arguments that the director should prefer light mode.

Dark mode remains the main review target. The appendix is a record for future maintenance, not a requirement to delay dark visual work. A theme repair, if later selected, should use dedicated foreground/background pairs rather than redefining global text and assuming every fixed-colour illustration will adapt automatically.

## Deliverables and traceability

- [Source ledger and access limitations](AFL_UI_STYLE_SOURCE_LEDGER.md)
- [Dark contact sheet](AFL_UI_CURRENT_DARK_CONTACT_SHEET.png) — twelve 390-wide states
- [Light contact sheet](AFL_UI_CURRENT_LIGHT_CONTACT_SHEET.png) — secondary appendix evidence
- [Exact colour calculations](AFL_UI_STYLE_CONTRAST_CALCULATIONS.json)
- `afl-ui-style-evidence/` — selected Training capture and capture manifest. All 74 original PNGs and the disposable capture harness remain in the local audit archive; the two contact sheets are included here. The manifest distinguishes local-only evidence from published files.

Key implementation references at the audited SHA: [UiKit](https://github.com/gabebartolo-spec/Afl-auto-battler/blob/75bb24ee5c987bd1fcaf21d22e02c92b876b4823/scripts/ui/UiKit.gd), [FormationView](https://github.com/gabebartolo-spec/Afl-auto-battler/blob/75bb24ee5c987bd1fcaf21d22e02c92b876b4823/scripts/ui/FormationView.gd), [MatchScene](https://github.com/gabebartolo-spec/Afl-auto-battler/blob/75bb24ee5c987bd1fcaf21d22e02c92b876b4823/scripts/ui/MatchScene.gd), [TrainingScene](https://github.com/gabebartolo-spec/Afl-auto-battler/blob/75bb24ee5c987bd1fcaf21d22e02c92b876b4823/scripts/ui/TrainingScene.gd), [ListScene](https://github.com/gabebartolo-spec/Afl-auto-battler/blob/75bb24ee5c987bd1fcaf21d22e02c92b876b4823/scripts/ui/ListScene.gd).

The canonical roadmap/Claude entry point now records all eight included scopes. This remains documentation and evidence only: it implements no gameplay or final visual treatment. Art-agent direction and the director's final appearance approval govern implementation.
