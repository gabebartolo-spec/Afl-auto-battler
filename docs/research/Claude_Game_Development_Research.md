# Developing video games with Claude: research and proposed interview

Prepared 6 October 2026. Research only. No roadmap, game code, agent settings or installed tools changed. All proposals below await the interview.

This pass concentrates on Claude as a **game-development workforce**: how it understands an engine, implements mechanics, diagnoses failures, produces assets, checks what players experience and spends your Max 5x allowance. It does not add another collection of game-design features. Your AFL project is the practical case study; the earlier project, workforce and RPG reports remain separate and unchanged.

The accompanying source register distinguishes direct reading, selected passages, abstracts and carried-forward evidence. Developer posts are self-reports; tool README claims are not reproduced benchmarks. I inspected your existing test and capture scripts, but did not run the game, install the integrations or independently play the reported games.

## The most useful conclusion

Your four-agent setup has enough capability to develop a substantial game. The biggest opportunity is to give those agents **better evidence of the running game**, then require evidence appropriate to the change before they call it finished. Increasing effort cannot compensate reliably for an agent that never sees the failing input path, inspects the wrong worktree or watches a fallback animation.

I would first reuse your current tools to connect a small playable AFL flow to input, state and visual evidence. Then improve debugging, editor ownership and task allocation around that flow. A new engine, an enormous agent framework and paid asset services are unnecessary prerequisites.

This is a recommendation derived from the research and your project inspection, not a claim that your current game has all the failures described below.

## What the evidence actually supports

The game-specific research is much less reassuring than general coding leaderboards. **SWE-Game** evaluates Godot creation, repair and porting tasks. Its executable checks agreed with human judgments better than its visual-language judging on the reported sample; the model configurations include Opus 5 rather than a controlled comparison of your 5.5 workforce. Its results support combining observable gameplay checks with visual review, rather than treating compilation or an agent's verdict as sufficient. They do not establish a Max-plan optimum. [SWE-Game](https://arxiv.org/html/2609.33678v1)

**GameDevBench** separates graphical and logical implementation work; adding visual feedback improved results in its experiments. **GameLogicBench** checks rules across gameplay trajectories and tests its evaluator against deliberately deficient implementations. My application to AFL is to test observable sequences and known failure cases, including whether input was needed to produce the claimed outcome. These studies support the verification method; their model and task mixes do not prove that a particular Claude setting will win on your project. [GameDevBench](https://arxiv.org/html/2602.11103v2), [GameLogicBench](https://arxiv.org/html/2609.21562v1)

Two further papers were read at abstract level: **GameCraft-Bench** evaluates complete Godot artifacts through replayed interaction, and **GameEngineBench** tests native C++ changes inside Unreal projects. Both report substantial gaps between generating recognisable work and completing the required behaviour. I use them as corroboration of the problem, not as a ranking of your agents. [GameCraft-Bench](https://arxiv.org/abs/2606.17861), [GameEngineBench](https://arxiv.org/abs/2607.03525)

**GUI Agents for Continual Game Generation** studies automated playtesting and iterative repair using browser games, including Sonnet 4.6. It makes a useful case for a playtest loop, but its browser scope and curated evaluation do not demonstrate autonomous assessment of a native Godot game's fun or mobile readiness. [Paper and limitations](https://arxiv.org/html/2605.28258v1)

These are research studies, several recent preprints, with different scaffolds and task definitions. Their success percentages are not comparable production forecasts. No study reviewed here gives a controlled answer to “Sonnet 5.5 Extra versus Opus 5.5 Medium on this AFL codebase.”

## The developer accounts worth learning from

I read 27 accessible, game-specific Reddit discussions, including successes, failed verification, cost complaints and tool builders. This is a deliberately varied sample, not a representative survey. The strongest lessons recur across accounts, but specific timelines, costs and shipping claims remain unverified.

| Account | Useful lesson | Limit on the claim |
|---|---|---|
| Six months building a Godot football manager on Max 5x | Particularly close to your situation: small playable milestones helped, while a cup-system debugging loop reportedly consumed many prompts over several nights | Self-report; older Claude behaviour; its advice to repeatedly remind Claude about project instructions conflicts with current automatic loading |
| Mobile-game postmortem by an experienced developer | Concrete visual direction and render debugging matter even when feature implementation is quick | An experienced developer's results do not establish novice autonomy |
| A Godot animation approved while its loader fell back | Review footage must be accompanied by proof that the intended system ran | One incident and a proposed review tool; not proof of a universally superior reviewer model |
| Opus 5.5 and Sonnet 5.5 building a mine-cart demo | The developer reported different defects and different playtesting behaviour from the two models | One pair of runs, subjective assessment, no controlled workforce-cost study |
| Unity game reportedly reaching Steam in ten days | Existing assets and concentrated integration can accelerate a small game | Purchased assets and technical submission success do not prove quality, longevity or equivalence to AFL |
| Unreal prototype reportedly built in 72 hours | Agent/editor access can coordinate a complex pipeline | The author also described manual asset cleanup and rigging; this was not an entirely autonomous production pipeline |
| Phone-directed procedural god-game demo | Plain-language visual feedback can be valuable; audio still needed human listening | A demo, with a custom browser runtime; not evidence that engines or asset pipelines are unnecessary |

Sources: [football manager](https://www.reddit.com/r/ClaudeCode/comments/1qknr1v/what_i_learned_building_a_full_game_with_claude/), [mobile postmortem](https://www.reddit.com/r/ClaudeCode/comments/1ryqig5/gamedev_with_claude_code_a_postmortem/), [fallback animation](https://www.reddit.com/r/ClaudeCode/comments/1wtuunu/claude_code_cant_watch_my_game_and_one_day_it/), [mine-cart comparison](https://www.reddit.com/r/aigamedev/comments/1wx2k3a/two_claude_models_built_the_same_mine_cart_game/), [Steam account](https://www.reddit.com/r/ClaudeAI/comments/1s7mfil/i_built_a_steam_game_in_10_days_with_claude_code/), [Unreal prototype](https://www.reddit.com/r/ClaudeAI/comments/1widtfq/i_used_claude_code_unreal_mcp_to_build_a/), [procedural demo](https://www.reddit.com/r/ClaudeCode/comments/1wxpk01/i_directed_a_god_game_from_my_phone_by/).

The useful success pattern is a director with a clear outcome, a limited playable target, usable engine feedback and repeated review. “Thousands of generated lines,” “one prompt” and “no coding experience” are weak measures of a finished game. Conflicting Reddit recommendations about engines and models should trigger an experiment, not a wholesale migration.

## What your AFL tooling already does well

The inspected repository already has a serious test runner. It imports the project, detects script and compilation errors, checks suite summaries and expected check counts, provides isolated run data, and supports CI sharding. This is materially stronger than the tiny starter harnesses promoted in many tutorials. Preserve it and add checks for demonstrated gaps.

You also already have dedicated Godot capture fixtures for matches, vignettes, press conferences, awards, guernseys and other scenes. Three inspected examples reveal an important distinction:

| Existing fixture | What it helps establish | What requires additional evidence |
|---|---|---|
| Vignette capture at 390 × 844 | A repeatable portrait presentation; staged moments; selected animation beats and an optional film sequence | The fixture emits a button signal, freezes processing and assigns animation times. That does not establish an ordinary user's input path or unmodified live timing |
| Match capture at 900 × 700 | Seeded match presentation, camera and trail diagnostics, manually advanced snapshots | Portrait phone layout, actual touch behaviour, packaged-device performance |
| Press capture at 360 × 792 | Repeatable scene composition and selected beats, with a cropped stage | Complete screen navigation, overlays, dialogue flow and real-time interaction |

These are complementary tools. Staging is useful for reproducible visual inspection; it should be labelled as staging. The new opportunity is a small interaction fixture alongside them, rather than removing their deterministic controls.

Your root `CLAUDE.md` is already concise and expresses the director's role, mobile intent, restraint, assigned scope and required testing. It also describes explicit art-review responsibilities. Preserve those. A research report does not override them or authorise agents to build arbitrary roadmap items.

## Proposal: define the proof before the patch

For each substantial feature, the implementing agent should establish the visible outcome and select the relevant evidence. The amount of proof should scale with the change.

| Layer | Question answered | Example for AFL |
|---|---|---|
| Build and integration | Does the change import, load and connect correctly? | New vignette resources exist; scripts compile; required signals connect |
| Behaviour and state | Does the intended input cause the intended consequence? | A selection is committed once, score state changes correctly, the resulting save survives reload |
| Appearance and motion | Does it communicate clearly and match the approved direction? | Choice text remains readable; bodies move naturally; an overlay does not obscure the ball |
| Packaged target | Does it hold up in the exported environment? | Portrait touch, navigation, resource loading and performance on the chosen device |

A roster-data correction will not require a movie. An animation change will. A scene-layout edit needs a rendered view at relevant sizes; a save-system change needs reload and failure-path evidence. These are proposed completion criteria, not a new four-layer ceremony for every typo.

Each evidence bundle should identify the commit or working-tree changes, engine version, relevant renderer, seed, scenario and capture method. Reuse remains valid where dependencies are unchanged. Do not invalidate every image after an unrelated documentation merge, and do not reuse images after changing the shader they depict.

The distinction between the agent's claim and the environmental outcome also follows Anthropic's evaluation guidance. My recommendation is to make that distinction concrete in game feature handoffs. [Anthropic on evaluating agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)

## Prevent the convincing false pass

The animation case is especially relevant to game development: an agent can inspect a plausible walk cycle while a missing animation caused the engine to use its fallback. A correct-looking screenshot can similarly come from a mock scene, an old texture, a disabled effect or the wrong project instance.

For animation and other runtime systems, capture the actual active resource or state alongside the footage. A clip showing a player's arms is stronger when its record also establishes that the requested animation was loaded and advancing. Record relevant fallback warnings, active clip/state, time progression and intended actor identity. Do not merely log a test driver's “walking” phase: that label can be correct while the game ignores it.

The open-source review plugin associated with the animation account supplies useful examples of full-resolution frame review, synchronised state and movie drivers. Its reviewer also prescribes a particular model and a forced binary verdict. I would adopt the evidence technique while allowing **pass, fail or insufficient evidence** and retaining your current roster. One model spotting one defect does not justify permanent model routing. [Review agent source](https://github.com/ProtoForgeSystems/protoforge-claude-plugin-game-review/blob/6b52b92cf5b2583462994f7c1710b93dd1317eec/agents/frame-review.md), [movie-driver source](https://github.com/ProtoForgeSystems/protoforge-claude-plugin-game-review/blob/6b52b92cf5b2583462994f7c1710b93dd1317eec/skills/godot-movie-driver/SKILL.md)

Test the checking mechanism itself with a known broken case: omit the requested clip, bypass the input response or substitute stale output in an isolated fixture. The checker must notice. Keep this small and relevant; it is a way to establish trust in a new check, not an instruction to duplicate every implementation in tests.

## Input testing needs the actual input path

A test that calls a button's callback proves different things from a test that sends a tap through the viewport. Overlay interception, hitboxes, focus and input consumption can fail while the callback is perfect. Godot's documented event pipeline includes GUI handling and propagation; changing an input action's pressed state is also different from delivering an event. [Input-event flow](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html), [Input API](https://docs.godotengine.org/en/stable/classes/class_input.html)

For a first AFL pilot, choose one ordinary path: open the relevant screen, select an option, start the match, encounter a moment, make its choice and verify the resulting state. Use deliberate setup only to reach an otherwise expensive scenario, then exercise the interaction being tested normally. Label desktop mouse simulation separately from device touch evidence.

When a tap does nothing, Claude should inspect the target rectangle, overlapping controls, event receipt and state transition before altering gameplay logic. That turns vague “button broken” debugging into a narrow investigation.

Pause and freeze behaviour also need care. Godot process modes determine which nodes continue while paused; signals can still execute when processing stops. A capture harness must understand those semantics rather than treating every continuing cosmetic effect as a game defect. [Pausing and process modes](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html)

## Motion review and performance review need different captures

Selected stills can expose clipping, silhouettes and composition. A continuous clip exposes a locked torso, abrupt transitions, foot sliding, contact timing and recovery poses. A contact sheet should help locate frames; reviewers should inspect relevant frames at sufficient resolution and view the movement over time.

A 12 fps sample can miss short events. Supplement footage with event timing where the defect involves a collision, input response or one-frame effect; increase capture rate when the visual question warrants it. Do not make every review a long, high-resolution film.

Godot Movie Maker deliberately produces fixed-paced output even when rendering takes longer in real time. That makes it useful for reproducible visual inspection, but a smooth offline movie does **not** establish smooth gameplay. Keep actual real-time capture and profiling separate. [Godot Movie Maker](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html)

For performance changes, give Claude a measured bottleneck, a representative scenario and before/after results from comparable conditions. Include intermittent stalls and loading where relevant, rather than average FPS alone. Some engine monitors have availability and update-rate limitations; empty values are not a performance victory. [Profiling](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html), [performance monitors](https://docs.godotengine.org/en/stable/classes/class_performance.html), [optimisation guidance](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html)

## Engine access: keep Godot, evaluate a small bridge if useful

There is no research basis here for moving AFL to another engine to accommodate Claude. Your existing Godot code, generated assets, captures and tests are valuable infrastructure. Current Unity and Unreal integrations do, however, invalidate older blanket claims that those engines cannot support agent workflows.

Unity announced a first-party Claude Code plugin in September 2026, with editor access and game-development skills. Epic documents an Unreal MCP server with requests executed serially on the game thread. These are current alternatives for projects already using those engines, not reasons to migrate AFL. [Unity announcement](https://unity.com/blog/unity-plugin-for-claude-code), [Unity plugin documentation](https://docs.unity.com/en-us/ai/unity-plugin/about-unity-plugin), [Epic MCP documentation](https://dev.epicgames.com/documentation/unreal-engine/unreal-mcp-in-unreal-editor)

For Godot, compare integrations by the missing capability they supply:

| Candidate | Potential value | Decision for your setup |
|---|---|---|
| Existing CLI, tests and capture fixtures | Already integrated, deterministic, no new service | Default foundation |
| `satelliteoflove/godot-mcp` | Runtime state, input scripts and freeze/step operations | Strong candidate for one optional free pilot, with connection and worktree checks |
| `minimal-godot-mcp` | Native language-server diagnostics and debugger integration | Consider only if it materially shortens diagnosis beyond current import/test feedback |
| Tann2019 GodotForge | Broad editor and runtime operations, engine documentation access | Alternative to compare selectively; do not load all capabilities by default |
| Beckett Godot MCP | Free observation features; more complete automation in a paid edition | Paid edition falls outside your free-tools rule; not necessary for the recommendation |

Sources: [runtime bridge](https://github.com/satelliteoflove/godot-mcp), [minimal bridge](https://github.com/ryanmazzolini/minimal-godot-mcp), [GodotForge](https://github.com/Tann2019/godot-mcp-server), [Beckett editions](https://github.com/beckettlab/beckett-godot-mcp).

The runtime bridge has a particularly relevant history: a report described one client displacing another, and a merged fix protects a healthy incumbent connection. It remains a **single-client** arrangement; that fix is not evidence that four agents can concurrently drive one editor. Its change record also distinguishes connection tests from a live two-client Godot integration test. [Issue 237](https://github.com/satelliteoflove/godot-mcp/issues/237), [merged fix 264](https://github.com/satelliteoflove/godot-mcp/pull/264)

A pilot should answer five questions: can the agent read a real error, identify the correct worktree, inspect runtime state, exercise an input sequence, and recover from an editor restart without interfering with another agent? Compare tool overhead, rework and useful results against the current workflow. Installation alone is not success.

Even established integrations have platform-specific failures. A Unity MCP issue reports PlayMode tests hanging on a Linux/Vulkan setup while other test routes worked. This is an argument for testing the integration in the actual environment, not a verdict that MCP or Unity is broken. [Reported test failure](https://github.com/CoplayDev/unity-mcp/issues/1390)

## Game-specific agent cooperation

Git isolation is necessary but incomplete. Two worktrees can still compete for an editor connection, a runtime port, generated output, an import cache or a save location. A handoff should therefore name the project instance and the owner of any active run or editor session. An agent must stop its own process, not broadly terminate every Godot instance.

Keep your four existing roles, with more explicit boundaries for a feature:

| Role | Suggested responsibility | Evidence it should hand over |
|---|---|---|
| Boss | Architecture, cross-system decisions, difficult diagnosis and integration | Chosen approach, affected contracts, integration risks and unresolved questions |
| Worker | Bounded mechanics, screens and associated verification | Actual changed behaviour, tests, input/state evidence and reproducible scenario |
| Admin | Assigned housekeeping, data work and concise coordination | Exact changes, authoritative check status, actionable next step |
| Art | Approved visual direction, asset integration and motion review | Consistent references, generated-asset identity and rendered output |

Roles should not require all four agents to discuss every tiny change. Use direct, actionable communication: “this resource contract changed; regenerate these two atlases,” rather than repeated summaries of the same status. A waiting agent should identify the dependency and resume when it changes.

Where one agent owns an editor bridge, others can continue read-only inspection, isolated tests and work in their own instances. If that architecture is too costly, schedule editor writes through one owner. Do not try to solve a single-client limitation with prompt etiquette alone.

For independent review, use another existing agent when the change warrants it. A review should receive the goal and evidence, then reach its own conclusion. Avoid priming it with “the animation is now excellent.” Your judgment remains the authority on style and feel.

## Models, effort and Max 5x efficiency

The recommendation remains task-dependent. Opus 5.5 is suited to open-ended integration and sustained judgment; its documented adaptive-thinking default is Medium. Anthropic also describes Sonnet 5.5 as especially complementary at lower effort, while higher effort increases work and cost. These are useful routing signals, not a game-specific Max-plan billing formula. [Opus 5.5 behaviour](https://platform.claude.com/docs/en/models/opus-5-5/whats-new-opus-5-5), [Sonnet 5.5 evaluation and effort](https://www.anthropic.com/claude-sonnet-5-5)

For your current roster, I would **test**, rather than immediately apply:

| Agent | Your stated setting | Proposed game-development allocation |
|---|---|---|
| Admin | Sonnet 5.5 Extra | Medium for routine bounded work; Low where verification is simple; escalate for a demonstrated reasoning problem |
| Worker | Opus 5.5 Medium | Retain as the implementation baseline; use High when a hard integration or repeated diagnostic failure merits it |
| Boss | Opus 5.5 High | Retain for architecture and difficult cross-system work; avoid using it for repeated status checks |
| Art | Opus 5.5 High | Retain for visual/motion judgment; consider Medium for mechanical generation and manifest updates |

These are refinements of the previous workforce proposals, not approved setting changes. More effort can improve difficult reasoning; it cannot provide a missing screenshot, engine error or active animation identity.

The earlier local usage audit found very large contexts and extensive cached input across the four agents. Those observations justify investigating unnecessary material and loops. They do not establish how many Max percentage points a particular file or cached token costs. Your screenshot's 150k warning is not a proven billing cliff, and API dollar equivalents would misrepresent your subscription.

Current Claude Code usage reporting can help identify context-heavy tools and interactions, subject to version and reporting limitations. Record the actual plan allowance before/after a comparable block of work where available. Keep request counts, tool activity, retries and accepted quality beside it. Do not infer exact subscription charges from the token fields. [Usage and cost documentation](https://code.claude.com/docs/en/costs)

Measure **accepted game changes per allowance and time**, including rework. A cheaper-looking model that makes several wrong patches can lose to a stronger model that diagnoses the bug once. Conversely, routine data edits do not need architecture-level reasoning. Start with a handful of comparable task families from normal work: scene input, seeded simulation, resource/shader integration, save behaviour and release housekeeping. Judge repeated examples before changing the whole workforce.

## Context should contain the game task, not the whole studio

A feature packet should give Claude the outcome, relevant files, engine version, scenario, owned work and acceptance evidence. Keep approved project policy in the concise root instructions. Put specialised factual rules near the files they concern, and detailed procedures in on-demand skills where worthwhile.

Claude Code documents automatic project-instruction loading, path-scoped rules and skills whose bodies load when used. Importing a large document into `CLAUDE.md` does not make that document free. This matters for game projects with giant roadmaps, asset manifests and test logs. [Project memory and rules](https://code.claude.com/docs/en/memory), [Skills](https://code.claude.com/docs/en/skills)

Do not mandate a fresh session at an arbitrary context size. Anthropic's long-running harness experiment found newer Opus behaviour could work with continuous automatic compaction, unlike earlier models. It also illustrates that a more elaborate multi-agent run can spend substantially more time and money while producing a larger result; it is not a matched-cost benchmark for your plan. My proposal is to renew context at sensible completed-work boundaries, preserve decisions and investigate redundant growth. [Harness experiment](https://www.anthropic.com/engineering/harness-design-long-running-apps)

Useful efficiency tactics for games include a compact state digest instead of repeatedly dumping the scene tree, relevant log excerpts instead of an entire console, a selected frame before a long film and a generated manifest diff instead of hundreds of unchanged asset descriptions. Keep the original evidence on disk for deeper inspection.

## Debugging: change the evidence when the patch loop repeats

After two or three substantially similar failed fixes, the agent should change investigation method. That number is a suggested warning trigger, not a prohibition on sustained work.

Ask it to preserve a reproduction, identify expected versus observed behaviour, collect the relevant runtime state and error, and test one competing explanation. Depending on the failure, use a minimal scene, a last-known-good comparison, a breakpoint, a resource audit or profiling. If it is an integration question, a fresh focused review may help. Turning every failed patch into higher effort or another agent is an expensive substitute for diagnosis.

Ground unfamiliar calls in the actual engine version and API. Godot exposes runtime class information, while its debugger provides stack and state inspection. CLI flags also require care: Godot documents that unknown arguments can be silently ignored, so a successful exit alone does not prove that a requested diagnostic mode ran. [ClassDB](https://docs.godotengine.org/en/stable/classes/class_classdb.html), [Debugger](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html), [Command line](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)

Keep code organised around boundaries that help diagnosis. A scene should not unexpectedly depend on a particular parent path; injected data and clear signals can reduce that coupling. Apply this where a recurring defect justifies it, rather than undertaking a blanket refactor of all procedural UI or existing scenes. [Scene organisation](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)

## Testing without turning verification into another token sink

Run the relevant checks during iteration, then the required project checks before delivery. CI should remain authoritative for its own complete run. Preserve your existing suite-count safeguards; do not replace them with an agent's “tests passed” statement.

Deterministic tooling can enforce common checks without asking an LLM to interpret every unchanged result. Hooks may help with a narrow, bounded check, but repeated blocking checks must not loop indefinitely. Use documented hook semantics and guards rather than copying unsupported commands from a tutorial. [Claude Code hooks](https://code.claude.com/docs/en/hooks-guide)

For simulation and balance work, use fixed seeds and paired comparisons when relevant, with independent random streams where isolation is needed. Record the engine version and assumptions; a fixed seed is not a universal cross-version replay guarantee. Show distributions and failures, not a single favourite match. The full content balance audit remains an already-discussed game item; this proposal concerns Claude's method of investigating it. [Godot random-number guidance](https://docs.godotengine.org/en/stable/tutorials/math/random_number_generation.html)

## Art, asset production and audio

Your MPFB → Blender → Python atlas → Godot pipeline already serves a particular visual direction and player-appearance system. Claude should improve its repeatability and feedback before introducing more generators. This pass does not validate the old Orc/Vampyr observations as an AFL animation defect.

Specify an asset contract: dimensions, pivot, scale, naming, colour conventions, animation layout, shader inputs and required metadata. Tie previews to the generated version and loaded Godot resource. Validate a representative example before producing a whole roster or regenerating every atlas. Extend the existing checks where they leave a demonstrated gap.

For animation, Claude needs contact poses, weight transfer, torso/arm contribution, transitions and rendered cadence as review criteria. The art agent can identify a plausible issue; the director should see the actual game-scale clip. A beautiful Blender view does not establish legibility in the portrait match scene.

Maintain a small set of approved references and reusable scene-dressing components. Generate backgrounds and foregrounds in context, with the actor, camera and text area visible. This makes the existing request to eliminate vignette voids concrete without authorising a fresh style change.

Developer case studies commonly combine Claude with purchased assets, manual rigging and paid image/mesh/audio services. I have not treated those services as free recommendations. The Unreal prototype account is useful precisely because it exposes the cleanup between generated art and a usable rig. [Unreal pipeline account](https://www.reddit.com/r/ClaudeAI/comments/1widtfq/i_used_claude_code_unreal_mcp_to_build_a/)

Audio needs an explicit evidence path too. A coding agent can inspect formats, duration, event triggers, levels and clipping, but that does not establish whether the soundtrack is pleasant, repetitive or well balanced. Do not claim listening took place unless the interface and review actually support it. Use human listening on the target output for final mix/feel decisions. The procedural-demo author reports that audio checking depended on their ears, including a mute-switch misunderstanding. [Audio experience](https://www.reddit.com/r/ClaudeCode/comments/1wxpk01/i_directed_a_god_game_from_my_phone_by/)

Claude can author and validate dialogue/content offline using stable identifiers and schemas. Keep generation separate from runtime content consumption. Nothing in this research requires paid live-model NPCs, an online dependency or rewriting the already-approved storytelling scope.

## Packaging and human playtesting

An agent should demonstrate important flows in an export as well as the editor when the change affects target behaviour. Use the exact build under review. Editor access, test autoloads, mock resources and capture-only behaviour should not silently become release dependencies.

For AFL, a small packaged smoke path could cover launch, a saved career, a match interaction and return/reload. Add portrait/device input and performance evidence where relevant. Build the infrastructure once, then select checks by risk. Android export has its own toolchain requirements; successful editor testing does not fulfil them. [Android export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)

Automated playtesting should handle reproducible rules and broken flows. Human playtesting should judge comprehension, pacing, emotional attachment and football feel. Use short, targeted sessions with familiar and unfamiliar players when practical. Claude can turn plain-language feedback into a reproducible investigation; the director should not have to provide a technical diagnosis.

The feedback packet can stay simple: what the player tried, what happened, what they expected and a short relevant recording where available. Do not turn every taste judgment into a bug or every AI success verdict into a claim that players enjoyed the game.

## Frameworks: borrow the useful parts

Large studio templates and game-development skill packs offer useful ideas for task routing, engine-version pinning and specialised checklists. They also create more configuration, duplicated policy and material to maintain. Their advertised agent count is not evidence of better games or lower Max usage. [Game Studios workflow example](https://github.com/AliVertigo/claude-code-game-studios/blob/main/docs/WORKFLOW-GUIDE.md), [game skill collection](https://github.com/gamedev-skills/awesome-gamedev-agent-skills), [LibreGameDev pack](https://github.com/HermeticOrmus/LibreGameDev-Claude-Code)

The BMAD game-development module explicitly describes boundaries around what it provides, including not producing art assets or complete games from scratch. It can inform a small planning procedure without replacing your workforce or being mistaken for an autonomous studio. [BMAD game module](https://github.com/bmad-code-org/bmad-module-game-dev-studio)

A more credible production example is Believer's **Claireon** Unreal integration. Its developer describes exposing a very broad editor capability set through a few discovery/execution tools, handling editor crashes and routing worktrees. The reported delivery gains are the studio's own claims, not an independent benchmark. The transferable ideas are selective discovery, compact output and reliable project routing; adopting its entire Unreal system would not fit AFL. [Studio account](https://believer.gg/introducing-claireon-our-open-source-unreal-plugin-for-agentic-workflows/), [implementation](https://github.com/believer-oss/claireon)

Jonathan Caruso's Godot harness is another useful concrete example of CLI checks and rendered feedback on a small game. Your existing test infrastructure is already broader; use it as corroboration of the feedback approach, not a replacement package. Its older engine comparisons must be read alongside the current official integrations above. [Developer article](https://www.jonathancaruso.com/blog/getting-claude-code-to-build-games-in-godot)

## Proposed interview, one decision at a time

None of these items is approved. Begin with C1; explain the difference from existing tooling before asking. Preserve the prior pending workforce question rather than interpreting your praise as acceptance. Combine overlapping approvals into concise actionable items only after the interview is complete.

| Order | Proposal to discuss | Initial scope / restraint |
|---|---|---|
| C1 | Require relevant running-game evidence for substantial changes | Pilot one AFL flow using current tooling; tests, actual interaction/state, and footage where motion matters |
| C2 | Add active-system and fallback checks | One animation or presentation fixture; prove it detects a known broken case |
| C3 | Add a small real-input smoke flow | Supplement staged captures; no replacement of all fixtures |
| C4 | Separate visual movie review from real-time performance evidence | Short motion clips, selected full-resolution frames, measured live conditions |
| C5 | Evaluate one free Godot bridge | Compare concrete missing capabilities with current CLI; retain only if useful |
| C6 | Clarify editor/runtime ownership across agents | Project instance, ports, run data and generated outputs; stop only owned processes |
| C7 | Introduce a repeated-failure diagnosis trigger | Change evidence after repeated similar fixes; no automatic abandonment of hard work |
| C8 | Use concise feature packets and specialised on-demand guidance | Preserve current root policy; no full-roadmap imports or studio-framework overhaul |
| C9 | Test game-specific model/effort routing | Small comparisons during normal work; include quality and rework; no invented Max billing formula |
| C10 | Add focused independent review where warranted | Another existing agent, evidence-led; director retains taste authority |
| C11 | Tighten asset identity and animation evidence | Existing pipeline, representative sample first, actual Godot output |
| C12 | Add audio evidence and human listening where needed | Technical checks plus actual mix/feel review; free existing tools |
| C13 | Add a proportionate packaged-build smoke path | Representative release flows and target checks; separate dev-only tooling |
| C14 | Improve Claude's handling of playtest feedback | Plain-language observations become reproducible tasks; preserve human judgment |
| C15 | Standardise seeded simulation investigations | Paired comparisons, assumptions, distribution and edge cases; use existing harness |

The recommended starting point is C1. It gives the rest of the workforce a clear definition of a demonstrated game change, while keeping the first implementation small enough to judge its value.
