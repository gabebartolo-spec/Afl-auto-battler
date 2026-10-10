## ARD-M8-006 — Release polish
**Status:** `TODO`  
**Priority:** `P2`  
**Autonomy:** `SUPERVISED`

Final pass:
- Android portrait QA,
- accessibility/readability,
- save robustness,
- performance,
- useful error states,
- no silent failure/fallbacks,
- remove debug UI,
- ensure critical game actions are understandable without external explanation.


**Approved visual styling:** STYLE-01–08 (§9.5) extend the existing UI/art owners with a dark-mode-first pass. STYLE-06 refines the existing M8-007 migration, not a new vignette system. See §9.5 for scope, dependencies, director decisions and completion gates.

**Approved flavour extensions:** FL-001/004 (§9.3) add sparse authentic voice and natural ground/crowd sound through existing writing/audio systems.

---

## ARD-M8-007 — Cinematic tactical vignettes
**Status:** `VERIFY` — the prototype/broadcast-vignette foundation is merged (#153); phone playtest still decides tactical-library expansion. Necessary new flavour scenes are separately authorised in FL-007 (§9.3).  
**Progress (2026-10-06, anti-aliasing):** per-draw anti-aliasing on the pitch (#472) and project-wide 2D MSAA 2x plus anti-aliased vignette lines (#478), director-approved; texture filtering and mipmaps passed to the art agent (`docs/research/PERF_BASELINE.md` has the import inventory and the GPU cost).  
**Priority:** `P3`  
**Autonomy:** `SUPERVISED`


### Speccy vignette — identify the incoming kick and show its football context (2026-10-07)
**Status:** `TODO`. **Priority:** `P2` — **medium priority**, independent of the broader P3 vignette audit. **Owner:** Claude with the existing vignette/Art Agent owners.

The director reports that **only the umpire is visible in the background** of the speccy vignette, leaving the incoming ball's origin unexplained. Specifically ask and answer: **“Who actually kicked the ball which leads to the speccy?”** Trace the current speccy trigger and authoritative event chain to identify the actual kicker, disposal origin, marking player and nearby contest participants. Do not assume the umpire kicked it or invent a player/kick that the simulation never recorded.

Watch the full sequence in motion and verify that the lead-in, incoming trajectory and scene composition tell a coherent football story. Show the actual kicker or establish their kick through a readable lead-in/wider shot or other clear continuity when they are outside the final camera view. Include relevant players and positioning so a lone background umpire is not the scene's only apparent explanation of where the ball came from. An umpire may legitimately be present; their presence must not substitute for the actual delivery and contest.

If the necessary kicker/origin context is lost between event capture and vignette playback, preserve and pass it through the existing event/presentation plumbing. Keep the correct named identities, teams, kits, ball ownership/path and recorded mark outcome. Provide a short before/after clip and an event-attribution/scene-context regression check; verify relevant angles and desktop/phone framing. Record any missing provenance honestly rather than adding a decorative fictional kicker. Existing appearance approval and merge gates apply.

### Artwork style, material, staging and anatomy consistency — director review (2026-10-07)
**Status:** `TODO`. **Priority:** `P3` — low priority with the broad visual audit. The specific speccy incoming-kick check remains P2. **Owner:** Art Agent leads visual judgement; Claude audits actual in-game integration and coordinates fixes under M8-007 / STYLE-06.

Check **all game artworks**, not just a few vignettes: shipped figures, clothing/kits, grounds/backgrounds, furniture, props, ball, portraits where present, UI illustrations/branding, trophies/medals/flags and other artwork, including older scene families. Record the build, actual assets loaded, reviewed families and any missing/unreachable material. Review at real game scale, representative close-ups and in motion where applicable; source sheets alone are insufficient.

- **Style mismatch:** look for overly emphasised **cel shading**, harsh shadow bands, excessive contrast/heavy outlines, inconsistent lighting direction/softness, palette/saturation, edge treatment, perspective, proportions and apparent resolution. Compare against the director-approved art direction and accepted assets; do not assume all cel shading is unwanted or erase intentional distinctions between gameplay, editorial and ceremonial art.
- **Poor textures and flat colours:** identify blurry, stretched, repetitive, low-detail or mismatched textures, surfaces that read as flat colour blocks, and materials without convincing texture, shading or depth. Inspect the final rendering to distinguish source-asset defects from shader/import/lighting problems. Add restrained material detail where useful rather than noise, photorealism or expensive effects by default.
- **Generic or impersonal furniture/objects:** inspect chairs, tables, lecterns, rooms, stands and other props for placeholder-looking shapes, anonymous repeated assets, inappropriate scale/materials and lack of believable football/club context. Propose purposeful locally appropriate details grounded in the scene and club identity; avoid decorative clutter or fabricated personal/history facts.
- **Players mimicking one another:** inspect the full scene for cloned postures, mirrored poses, synchronised gestures/running loops and identical gaze/facing that make individuals look staged or robotic. Vary pose, timing, attention and stance according to each person's actual role/action, preserving necessary coordinated football behaviour and the recorded outcome. Do not rely on random pose variation that creates inappropriate movement.
- **Uncanny or inhuman anatomy:** check body proportions, limb lengths/joints, hands/feet, shoulders/neck, torso twists, balance/weight bearing and contact with ground, furniture, ball and other players. Flag impossible bends/reaches, dislocated-looking limbs, clipping, foot sliding and camera-induced body distortion. Verify across body sizes, poses, actions and viewing angles rather than fixing only one still.

Deliver a concise issue log with labelled side-by-side examples or timestamped clips, asset/scene/build, observed defect, severity and likely source (clearly separating hypotheses). Propose coherent local fixes for director review and verify before/after in real scenes. Preserve readability, identity/kits, performance and final appearance approval; do not roll out an unapproved global restyle or mark all artwork checked from a small sample.

### Director instruction — watch vignettes for visual and motion defects (2026-10-07)
**Status:** `TODO`. **Priority:** `P3` low priority (director clarification, 2026-10-07); schedule after higher-priority implementation and correctness work. **Owner:** Claude performs the actual runtime/motion audit and coordinates fixes with the Art Agent and existing vignette owners. Extend this item and its existing defect records; do not create a duplicate audit or assume earlier still-image approvals prove motion quality.

**Watch the vignettes playing in the game.** Review complete sequences in motion at normal speed, with slow playback/frame inspection to diagnose defects. Cover the available tactical decisions and branches, pre-match, scoring/snap/set-shot/pack, press conference, awards and other existing vignette families; record unavailable or unreachable sequences honestly. Inspect current main and relevant pending fixes separately, recording build/commit and the assets actually loaded. Reuse current capture tooling and existing clips where they prove the current build; code inspection, test passes and attractive stills alone do not satisfy this task.

Check specifically for:
- **Rogue ball transportation:** teleportation, hovering, skating/sliding, receiver-seeking paths, implausible spin, wrong ownership, hands/boots losing contact, duplicate balls, and unnatural transitions between hold, release, kick, flight, bounce and collection. Reconcile the actual event, named participants and outcome; do not fake a football result to hide a visual error.
- **Awkward limbs and contact:** bent/dislocated-looking joints, twisted arms/legs, impossible reach, disconnected hands, poor kicking/marking/tackling poses, penetrations and inconsistent foot-to-ground or hand-to-ball contact.
- **Robotic running:** stiff or synchronised loops, foot sliding, implausible stride versus travel speed, abrupt starts/stops/turns, wrong facing and broken transitions between idle, running and football actions.
- **Artefact aberrations:** seams, halos, jagged/pale edges, mask/atlas bleed, flicker, popping, missing layers, incorrect depth/occlusion, detached hair and discontinuities between frames. Verify the already merged seam repair and pending animation fixes before proposing another fix.
- **Clothing oddities:** warped/floating guernseys or shorts, clipping, inconsistent kit/skin coverage, sleeve/sock/tape/tattoo placement, colour/pattern/number changes and identity mismatches across poses or shots.
- **Perspective warping:** inconsistent player/ball scale, stretched bodies, implausible foreshortening, wrong ground contact/depth, distorted camera transitions, cropping that hides the football action and actors jumping relative to the scene.

**Deliver evidence and follow-through:** provide a concise itemised defect log with vignette/branch, build, timestamp or frame, clip/capture, observed problem, severity and owner; distinguish confirmed defects from hypotheses and sequences not exercised. Prioritise ball/contact/identity correctness and conspicuous repeated animation defects, then presentation polish. Fix confirmed issues within existing authorised scope and provide before/after motion evidence, relevant regression checks and rechecks across representative body sizes, kits, poses, camera distances, normal/fast/skip playback and desktop/phone layouts. Do not rerun unrelated broad audits or rewrite the motion engine without demonstrated need. The Art Agent leads visual treatment and the director approves final appearance; preserve existing merge/review gates and the Stats patch's single highest priority/HOLD. Do not mark this audit DONE from a static screenshot or claim native-phone motion/performance was checked when it was not.


Use short, deliberately higher-detail tactical vignettes for selected high-value in-match decisions so the player can **see the football problem or opportunity**, not just read about it.

This is **not** a full 3D match engine or a replacement for the standard watched-match view.

### Director addition — red/yellow match-ball colour consistency
**Status:** `TODO`

Support yellow footballs as well as red ones, including yellow balls in appropriate match vignettes. Choose the ball colour once from the match context and use that same value throughout the entire match: preparation/match intro, live match view, stoppages, scoring/action vignettes and any replay of that match. Do not choose a random colour independently for each scene or hard-code a red ball into shared vignette assets.

Claude should refine the simplest appropriate selection rule from existing match scheduling/context (for example day versus night where that information exists), with a stable default for older saves or missing metadata. Preserve the colour through save/reload and reused scene templates; use a shared match value rather than separate presentation guesses. Validate one red-ball and one yellow-ball match across views and vignette transitions, including reload, so the ball never switches colour within a match.

### Dependency
Do not prioritise this until the current §1.11 playtest gate has proved that the underlying decisions themselves are informed, meaningful and give useful feedback. Better presentation must not be used to disguise arbitrary choices.

### Prototype first
Build **one** centre-stoppage decision vignette before committing to a library.

The prototype should use enlarged 2D / 2.5D presentation only. Do not introduce 3D player models or 3D match presentation.

A successful vignette should:
- enter briefly from the normal match view;
- show only the relevant players and space, not all 36 footballers;
- use the actual clubs/players/context from the match state;
- play a short tactical sequence, then freeze at the decision point;
- visually expose the problem/opportunity — e.g. an opponent getting goal-side, a spare defender, an isolated forward, or a numerical advantage;
- present the normal decision UI over/after that readable situation;
- return cleanly to the standard match view.

### Reuse model
If the prototype earns expansion, prefer a small reusable library of situation templates rather than bespoke cinematics.

Possible families:
- centre clearance / stoppage,
- defensive transition,
- forward isolated one-on-one,
- spare defender / loose player,
- kick-in press,
- wing/outside overlap,
- forward stoppage,
- late-game flood / protect-space situation.

### Director addition — match vignette decision gates (2026-10-06)
**Status:** `TODO` — requested roadmap candidates for Claude to refine; no implementation in this update.

Extend the existing stoppage/kick-in/forward-entry/contact families with:
- **Stoppage setup — body block on their star midfielder:** show a selected teammate setting a block/screen to impede the opposition star midfielder and create room for the intended ball winner. Make the target, blocker and space readable. The setup, contact, escape and any infringement/outcome must follow the actual football event and existing rules; it must not silently disable the star.
- **Kick-out after a behind — torpedo down the centre:** show the kick-in set play, central receiving/contesting setup and a long torpedo through the middle. Show the genuine distance/territory opportunity and the central-turnover/exposed-defence risk where relevant. Do not assume a clean reception or invent a successful exit.
- **Inside-50 kick into space — running forward chase, collect and shoot:** show the kicker placing the ball into open space inside 50, the actual forward racing toward it with the relevant opponent, the ground-ball collection and kick for goal when the authoritative sequence supports it. This is a kick into space and running collection, not a generic overhead mark; preserve believable bounce, timing and pursuit, and allow the real miss, turnover or defensive interruption rather than force a goal.

- **Hip and shoulder — high-impact, risky bump:** a well-executed bump can be incredibly effective at removing an opposition player from the immediate play and opening space or preventing their involvement. This means taking them out of that contest/sequence, not guaranteeing an injury or removal from the match. Preserve the trade-off: a poorly executed or illegal bump can concede a free kick, with a **very small chance** of a report and potential suspension when the actual incident warrants it. Claude should refine effectiveness and risk using relevant player skills/traits, discipline, positioning and contact context; neither outcome should be a context-free random roll or a universally best call. Integrate legitimate contact, infringements and report/suspension consequences with ARD-M3-007 and ARD-M3-011 under their balance gates. The vignette must agree with the authoritative contact, free and report events; a report does not automatically imply a suspension, and any later ruling belongs to the existing MRO process.

- **Switch — open player on the fat side:** show a credible kick to an open teammate on the opposite wing, shifting play toward the less congested side to open attacking avenues and create better looks inside 50. Make the receiver, opposition shift and available forward space readable before the choice. Retain a meaningful cost/risk such as the longer ball's interception exposure, time for the defence to recover or loss of a more direct opportunity; suitability follows actual space, pressure and kicking ability, not a universal switch bonus.

**Director requirement: every concept above is a decision gate**, not merely an automatic highlight or post-event cinematic. Show the real setup/opportunity, freeze **before** the relevant call is committed, present meaningful alternatives and concise football trade-offs, and let the player's choice feed the authoritative MatchSim decision/outcome. For the running-forward scene, the gate comes before choosing the kick into space; the chase/collection/shot is the consequence only if it occurs. For contact, the gate comes before committing to the block/bump; for kick-out/switch, before choosing the disposal. If an appropriate gate or behaviour is missing, extend the existing decision system (ARD-M4-001) and football owner before illustrating it. Avoid repetitive prompts: trigger only at meaningful, context-valid opportunities and retain normal match pacing. Validate that alternatives genuinely change behaviour, risks can materialise, AI has equivalent football choices and outcomes are not predetermined by the vignette.

**Success/failure endings where appropriate:** every applicable vignette should have alternative endings driven by the authoritative outcome roll after the player's decision. The vignette must consume that result, never reroll it, and save/reload must preserve it. Define success/failure relative to the chosen action, not merely whether the possession ultimately produces a goal. Examples: the block creates room versus the star escapes/the block infringes; the torpedo reaches the intended contest/receiver versus an intercept or failed exit; the running forward collects and converts versus being beaten to the ball, dispossessed or missing the shot; the bump removes the opponent from the play versus being evaded or conceding a free; the switch opens a useful attacking route versus being cut off or allowing the defence to reset. Support intermediate outcomes when the actual event requires them (for example a successful collection followed by a missed shot); do not fabricate a binary result that contradicts the football sequence. A rare report may follow the genuine incident and is separate from the later MRO ruling. Pure scene-setting/ceremony vignettes need no artificial success/failure roll. Validate forced/seeded success and failure branches, relevant intermediate outcomes and reload determinism.

Use the existing pre-rendered 2.5D style, real participants/club identity and the same match ball colour throughout. Claude should inspect which sequences already exist and reuse their templates; any missing football behaviour belongs to the existing stoppage/coaching, kick-in (ARD-M3-009) or forward-entry/scoring owner, rather than a second cinematic simulation. Each scene must preview its meaningful decision and freeze at the appropriate point; any subsequent outcome sequence shows only what actually happened after the chosen call. Keep scenes brief/skippable and verify participant/event agreement, ball path, phone readability and performance under the existing vignette gates.

### Guardrails
- MatchSim remains the authority. A vignette may illustrate state but must not invent a second football outcome.
- Vignette participants must come from MatchSim's authoritative participant selection for that event (for centre bounces, the same ruck contestant and centre-bounce attendees), not a separate presentation-only reconstruction from generic position slots.
- Do not introduce 3D player models, 3D stadium presentation or continuous 3D match recreation.
- Do not build hundreds of unique scenes.
- Tactical readability matters more than graphical fidelity.
- Preserve club colours and player identity where useful without requiring licensed likenesses.
- Player identity includes credible visual diversity: never default every vignette player to the same white/light-skinned appearance. Use appearance data for rendering rather than racial/ethnic gameplay categories or name-based inference.
- Keep mobile performance and load time within the Android-first target.
- No extra number-vomit: the visual should replace explanation where possible, not add another analytics layer.

### Prototype (2026-09-30)
Started on the director's direction, ahead of the §1.11 gate. The director asked for a *cinematic* scene, not an enhanced moment card.
- **Where:** the late-game centre-bounce call (MatchSim's `bounce` moment: Q4, a margin within two goals, at a centre bounce). No other moment changed.
- **The scene (`scripts/ui/match/StoppageVignette.gd`, about 4 s, a tap skips to the freeze):**
  - the match cuts in with letterbox bars;
  - a low camera behind your end pushes in on the centre square;
  - the real rucks and centre-square midfielders, in club colours, jog into their set-up, and anyone running on empty arrives last;
  - the umpire walks in and bounces the ball, and the rucks go up;
  - it freezes at the top of the contest, with a flash and the key names.
- **The call:** it slides up over the frozen frame with one or two commentary lines in words and no numbers (how the stoppages have gone, who is out on their feet), then MatchSim's own options. Choosing fades the scene back into the match.
- **Authority:** it is presentation only. It reads MatchSim's state (players on the ground, energy, clearances and hit-outs) and MatchSim resolves the call. There is no second simulation.
- **Tests:** `run_matchday_tests.gd` `_bounce_close_up` covers the following:
  - MatchSim raises the call;
  - only the stoppage players from this match appear;
  - it plays in and then freezes, and the options stay disabled until the freeze;
  - the commentary comes from the match, with no stats;
  - MatchSim takes the call;
  - the scene cuts back to the match.
- **Review:** `tools/visual/capture_vignette.gd` renders a contact sheet of the beats on a phone.
- **Not built:** templates, other families, or a framework. These wait for the playtest below.

### Figures (2026-10-05)
On the director's direction, the drawn stick figures became pre-rendered 2.5D footballers - still 2D in the game, no 3D models.
- **What:** one sprite sheet (`assets/vignette/figures_*.png`) of rigged footballers rendered offline from a front and a back camera pitched like the vignette's: an average build (midfielders, umpire) and a taller ruck build; idle, jog, ruck leap and the umpire's bounce. `figure.gdshader` recolours them per club at draw time, so one sheet serves all 20 clubs; your players show their numbers. `VignetteFigures.gd` (generated) holds the layout.
- **Where they come from:** the separate `ard-asset-pipeline` repo (`build_vignette_figures.sh --install`), from a CC0 MPFB body; rebuilding reproduces the sheet exactly.
- **Unchanged:** the camera, beats, positions, who is shown and MatchSim's authority. The pre-match scene uses the same figures.
- **Appearance:** each figure wears its player's skin tone and hair colour (`GameDB.player_looks`); see the "Vignette player representation / appearance bug" item for how the data is curated.
- **Guernsey designs:** each club's home kit is a row in `data/clubs.csv` ("guernsey": `<design>:<base>/<pattern>/<pattern 2>[/<shorts>]`, each colour p, s or a - the club's primary, secondary or accent - or a written-out `#RRGGBB`; e.g. Richmond `sash:s/p/a`, Port Adelaide `chevron:s/#FFFFFF/p`). Designs: plain, stripes, hoops, sash, yoke, band, chevrons, panels, chevron, sides, tiers, shoulders, map. The shader draws the design from where each pixel sits on the guernsey; socks take the base colour with a band in the pattern colour; back numbers are edged in the base colour so they read across stripes. Shorts left out are the secondary colour, a shade darker. Club emblems on the guernsey (the GWS "G", the Eagles' eagle) are not drawn. `tools/visual/capture_guernseys.gd` shows every club, front and back (`--scale`, `--clubs`). Brisbane, Gold Coast, GWS, Port Adelaide and West Coast follow the director's reference images; Tasmania wears its 2024 foundation guernsey (`map:p/s/a/p`: myrtle green, the primrose map of Tasmania on the chest with a rose-red T, green shorts); Canberra (an expansion club) has none. Every club's shorts are set, from its home kit: navy for Adelaide, Carlton, Geelong and Melbourne; black for Collingwood, Essendon, Port Adelaide, Richmond and St Kilda; maroon for Brisbane, red for Gold Coast and Sydney, purple for Fremantle, charcoal for GWS, brown for Hawthorn, blue for North Melbourne, West Coast and the Bulldogs, green for Tasmania; Canberra in its navy.
- **Tests:** `_bounce_close_up` checks the figures wear both clubs' colours and the sheet holds every move the scene plays.

### Phone playtest visual defect — boundary snap white arc

- **Snap from the boundary vignette has a strange curved white line — TODO.** Inspect the reachable boundary-snap vignette and remove the unintended curved white stroke/arc. Determine whether it is a stray trajectory/path guide, debug geometry, mask/outline artefact, sprite edge, or another rendering layer before changing it. Preserve any intentional ball-flight/readability cue only if it clearly belongs in the scene; the final vignette should not contain an unexplained white curve. Verify in motion and in phone-sized captures, including dark mode, so the repair does not merely hide the artefact in one frame.

### Complete vignette art-style replacement — director requirement, 2026-10-05

**Status:** `TODO` — required migration; the centre-bounce and pre-match conversion does not complete this work.

**Direction:** entirely replace the old vignette art style with the new pre-rendered 2.5D footballer style described above. This applies to every existing vignette and cinematic sequence, including tactical/match moments, broadcast sequences, pre-match scenes and awards/medal walk-ons. No old stick-figure or silhouette-style vignette may remain in the player-facing game.

**Scope:** inventory every vignette renderer, scene, animation and fallback that still uses the old style. Migrate all of them to the shared new figure assets and rendering approach, extending poses or animations where a sequence needs them. Preserve each scene's purpose, pacing, authoritative participants, club guernseys, player numbers and appearance data. Replace the awards ceremony's legacy BroadcastVignette silhouette figures as part of this work. Retire obsolete rendering paths and unused assets once their replacements are verified.

**Acceptance:** the inventory accounts for every existing vignette/sequence and each entry has been migrated and visually checked; no reachable scene or fallback displays the old art style. All scenes consistently use the new style, including awards and less frequent match moments. The migration requirement is replacement of existing presentation. The director's later FL-007 approval (§9.3, 2026-10-06) separately authorises necessary new flavour scenes; it does not authorise unrelated tactical-library expansion.

**Validation:** deliberately reach or capture every sequence and relevant fallback, compare phone-sized stills and motion, and check transitions, club colours, player appearance and pose coverage. Verify phone performance, skip/touch/Back behaviour and unchanged football outcomes. Obtain director visual review before marking the migration complete; record any untested sequence as outstanding.

**Director-requested follow-up — TODO (2026-10-06):** Flesh out vignette **backgrounds and appropriate foregrounds** to remove uncanny voids/dead space. Include contextual crowds, rooms, audiences, furniture and atmospheric items; Brownlow/press-conference scenes can use foreground tables, silhouettes or microphones. Match the shared art style, preserve action/UI readability and phone performance. Inspect every scene in phone-sized stills and motion for coherent, inhabited settings.

### Free shader polish — high-priority director request, 2026-10-06

**Status:** `TODO`. **Priority:** `P1` (high). **Autonomy:** `SUPERVISED`. **Owner:** art agent for visual direction; Claude for Godot shader/drawing integration. Extends ARD-M8-007 and LS-01–05; coordinate pitch work with ARD-M8-003 / STYLE-04. This is scoped shader polish, not a blanket promotion of all lighting experiments or a new art system.

**Goal:** improve depth, grounding and action readability using free code/tools/assets, without a major phone performance or battery regression. Preserve the existing figure shader's club guernseys, skin/hair, numbers, mirroring and packed-data contracts. Keep the Mobile renderer and the existing idle redraw policy.

**Recommended first slice:** compare restrained character shadow/highlight/contrast adjustments in `assets/vignette/figure.gdshader` using the existing lighting samples, subtle ground-only shading, and softer small contact shadows. Keep text, pitch markings and gameplay information clear. Reuse LS-01/03 shadow and environment work; do not duplicate it.

**Optional comparisons:** a small local ball/selection/goal radial effect only where it improves football readability; a thin, atlas-safe character outline only if phone captures justify its extra texture samples. These are candidates for art-agent/director review, not a mandate for decorative glow or a competing UI style. Preserve the existing editorial UI.

**Free implementation references:** [CC0 radial gradient](https://godotshaders.com/shader/radial-smooth-radial-gradient/), [MIT outline example](https://godotshaders.com/shader/2d-outline-stroke/), and [Godot colour-adjustment example](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html). Adapt older syntax and preserve licence notices where required. Fold colour maths into the existing pass where possible rather than adding a screen-reading pass. No paid shader pack or subscription is required.

**Performance/review gate:** record fixed-state before/after stills and motion on the actual Mobile renderer and weakest supported Android phone; include the crowded pre-match scene, tactical/broadcast scenes, mirrored figures, contrasting kits, skin/hair and readable jumper numbers. Compare CPU/GPU frame time, slow frames, draw calls, texture memory, loading/first-use stutters and sustained heat/battery behaviour against baseline. A proposed initial budget is under 1 ms extra frame time with no new sustained FPS drop; agree the device budget from measurements, not this estimate. Preserve the 60 FPS cap and low-processor idle behaviour. Keep an inexpensive fallback. Full-screen bloom/blur, elaborate dynamic shadows and normal-map lighting are not default scope; LS-04 remains a separately measured experiment. Existing final appearance approval applies; roadmap acceptance is not rendered/device verification.

### Free textures, artefact reduction and anti-aliasing — high-priority director request, 2026-10-06

**Status:** `TODO`; verify already-landed art/import fixes before implementation. **Priority:** `P1` (high). **Autonomy:** `SUPERVISED`. **Owner:** existing art agent / Claude rendering integration, coordinated with LS-01–05, ARD-M8-003 and STYLE-04/06. The director has included these findings as high-priority work. Use free software and freely licensed assets only; no paid pack, subscription or integration dependency.

**Texture work (extend LS-02/03):** improve broad folds, seams, boot/hair separation and baked material/lighting detail through the existing Blender pipeline. Prototype one football environment and one press/awards setting with restrained grass/soil, walls/floors, wood or fabric where appropriate. Reuse [Poly Haven CC0 assets](https://polyhaven.com/license), [ambientCG CC0 assets](https://docs.ambientcg.com/license/) or authored procedural surfaces; [Material Maker](https://www.materialmaker.org/) is an optional free tool, with third-party material licences checked individually. Bake useful surface detail offline where possible. Compare supersampled source renders downsampled into the existing atlas size before increasing runtime resolution. Preserve the grayscale shade/data channel contract, aligned masks, club patterns/numbers and per-player identity; no separate full atlas per club, unreviewed photorealistic shift, blanket noisy detail or texture swimming. Top-down PitchView currently draws geometry, so ground texturing is a deliberate extension of its existing surface treatment, not replacement of an existing grass asset.

**Artefact work (reuse A4 and existing visual defects):** reconcile the active art branch and actual imports. At the research snapshot, main still compressed the packed figure mask; compare lossless data against compression and verify whether A4 has since landed. Keep semantic weights/coordinates accurate and avoid ordinary alpha-border colour dilation on packed data. Preserve appropriate compression on visual atlases only after a measured quality/memory comparison. Reproduce atlas seams, mirrored hair/number alignment and the existing unexplained curved white line; determine the actual source rather than hiding defects with blur.

**Anti-aliasing sequence:** first compare supported per-draw antialiasing for oval boundaries, arcs, rings and token outlines. Then compare MSAA 2D off/2x/4x for geometry that needs it on the actual Mobile renderer. MSAA does not repair transparent sprite silhouettes, shader-internal aliasing or font rendering. Preserve existing fwidth-based guernsey-pattern smoothing. Test selective mipmaps plus matching mipmap-aware filtering for shrinking visual textures; provide atlas gutters/aligned layers and check frame bleed. Do not blindly average packed coordinate/semantic maps. Improve offline alpha coverage and visual borders; premultiplied alpha is a separate coordinated shader/blend experiment, not an import-only toggle. No default full-screen blur or supersampled runtime viewport.

**Acceptance/order:** capture fixed-state phone-scale stills and motion; resolve data/edge artefacts, then local AA/filtering, then texture/shader polish. Compare all relevant facings, kits, hair, numbers, fine pitch lines and UI text. Record CPU/GPU frame time, slow frames, decoded memory, load time and battery impact on the weakest supported Android phone. Mipmaps add roughly one-third texture memory; larger textures/MSAA are not assumed free in performance. Reuse LS-05 and existing director appearance approval. No production quality/performance improvement is claimed until implemented and verified.

**Technical references:** [Godot 2D antialiasing](https://docs.godotengine.org/en/stable/tutorials/2d/2d_antialiasing.html), [image importing](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html), [GPU optimisation](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html).

### Free lighting and surface detail — director follow-up, 2026-10-06

**Status:** `TODO` — findings recorded; no lighting/material prototype or rollout completed. **Priority:** `P2`. **Autonomy:** `SUPERVISED`. **Owner:** art agent, with Claude handling pipeline/render integration. Extends this task's existing figure/style and background/foreground work; do not create a competing art system. [Research and free options](research/AFL_Free_Lighting_and_Surface_Detail_Research.md).

**Goal:** improve volume, grounding and material distinction in players, environments and appropriate props while retaining the approved 2.5D style, club/player identity, action/UI readability and Android budget. Current source inspection found material roughness already differs for boots/skin/fabric; the shade atlas carries a single grayscale lighting multiplier. The sun's cast shadows were disabled because of acne, and the stoppage scene already supplies lift-aware ground ellipses. Inspect current art branches before treating these observations as missing features.

**Actionable sequence:**

- **ARD-M8-007-LS-01 — Baseline and offline lighting pilot:** reconcile the active art branch and installed Blender/API version; preserve current captures and material/channel settings. Compare the existing light rig with softer key/fill and optional free HDRI-assisted lighting on one standing and one moving figure. A small Cycles reference is optional; keep production rendering reproducible. Improve contact/crease shading without blindly restoring the sun-shadow acne. Reuse/refine existing ground shadows and keep them coherent with lift, light and environment. Choose settings from rendered evidence, not assumed quality from a renderer name.
- **ARD-M8-007-LS-02 — Restrained material detail:** prototype fabric relief/roughness, boots, hair and subtle skin variation using Blender procedural nodes first. Prefer visible folds/seams/highlight separation over noisy microdetail. Details follow body/garment coordinates through animation; retain masks, club patterns/numbers and curated player appearance. Specify how any colour detail survives the current grayscale shade pass. No uniform noise overlay, screen-space texture swimming or new atlas channel without a documented contract.
- **ARD-M8-007-LS-03 — Environment/prop materials:** improve one existing outdoor scene and one existing awards/press setting, coordinating with the already-requested scene dressing. Use a small coherent palette of grass/soil, fabric, wood, walls/floors and relevant foreground surfaces, with actor/background light direction and contact shading matched. Compare reusable texture/procedural or offline-rendered treatments; no mandatory conversion of all drawn scenery and no live 3D migration.
- **ARD-M8-007-LS-04 — Optional runtime-lighting experiment:** only where LS-01–03 leave a meaningful gap, compare a small Godot 2D normal/specular-lighting prototype with the cheaper baked result. Adapt the custom packed-data figure shader deliberately, preserve UI light isolation and avoid lighting baked shade twice. Verify per-frame alignment, mirrored/facing normal orientation, actual mobile renderer and memory/frame-time costs. Colour-derived relief may mistake dark kit stripes for dents; do not feed packed masks/design data to automatic normal generation. This is an experiment, not a committed new atlas or renderer dependency.
- **ARD-M8-007-LS-05 — Review, budgets and selective rollout:** provide lighting-only, detail-only and combined before/after comparisons at fixed state and phone scale, including motion, light/dark club kits, representative skin/hair and multiple facings. Record build time, atlas sizes/count, decoded texture memory, loading, draw calls and representative real-time frame time; preserve the project's existing phone/performance gates. Reuse capture/check tooling. Expand only after the art-agent recommendation and director's final appearance decision; record validated implementation and merged commit before DONE.

**Free options verified:** [Poly Haven](https://polyhaven.com/license) HDRIs/material assets and [ambientCG](https://docs.ambientcg.com/license/) assets are CC0; use free individual downloads and record asset IDs, licences and scale/settings. [Material Maker](https://rodzilla.itch.io/material-maker) has a zero-cost name-your-own-price release and can author reusable static textures; Blender already covers the first experiments and [Krita](https://docs.krita.org/en/reference_manual/brushes/brush_engines/tangen_normal_brush_engine.html) is an optional painting/normal-map route. Check community recipe licences separately. No paid subscriptions, asset generators or integrations required. **Laigter is not a free-binary recommendation:** its current developer page says binaries are paid despite the older Godot documentation wording; source compilation is optional and unnecessary for the baseline.

**Completion/guardrails:** research inclusion does not approve a final look. Follow the existing art-agent authority and director appearance gate. No MatchSim/gameplay/save changes, new tactical families, UI-wide grain/glow, photorealistic style shift, baked-club-colour duplication or full-roster regeneration before a representative approved sample. Validate animation/alpha edges, guernsey and number legibility, silhouette/skin identity, compression shimmer, and text/ball/action clarity. An offline movie is visual evidence, not real-time Android performance proof. Preserve existing migration, FL-007 and STYLE-01–08 boundaries.

### Acceptance test
The feature earns further work only if a phone playtest shows that the player can explain **why the decision is being asked**, form a reasonable expectation before choosing, and finds the moment materially more engaging than the normal presentation.

### Research refinement — 2026-10-05

**Dependencies / status boundary:** keep VERIFY and the §1.11 gate. The merged centre-bounce prototype is the current tactical owner. The earlier research did not authorise a new library; the later FL-007 approval (§9.3) permits necessary new flavour scenes only.

**Smallest scope:** test the existing scene against its authoritative participants, frozen state, choice and resumed events.

**Exclusions:** 3D, narrative event cards, fabricated movement implying an unapplied tactic or a separate outcome model.

**Acceptance:** viewers can see the football opportunity and trade-off; skip and watch preserve the same choice/resolution; repeated entry/Back does not duplicate or drop a call; positive and negative outcomes both return cleanly to the oval.

**Validation:** participant/event agreement, quiet/invalid contexts, 320/360/430-width review plus native Android touch, pacing, load time and performance. Tactical-scene expansion requires the director's phone finding that this presentation improves meaningful decisions. FL-007 flavour scenes have explicit director approval and are validated for recognition, visual distinction, pacing and gameplay neutrality instead.


**Approved flavour extensions:** FL-002/003/007 (§9.3) use the shared art/rendering pipeline. The director expressly authorised necessary new ritual, milestone, retirement and awards scenes on 2026-10-06. This scoped flavour permission supersedes earlier no-expansion wording for those occasions only; unrelated tactical-scene expansion retains its decision-clarity gate.

---


